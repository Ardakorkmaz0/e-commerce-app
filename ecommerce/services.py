"""
Cart operations.

Every write locks the product row it touches. Two shoppers racing for the
last unit is the normal case in a store, not an edge case, and the check
and the write have to happen together for the answer to mean anything.
"""

from django.db import transaction

from django.utils import timezone

from .models import (
    Cart,
    CartItem,
    Order,
    OrderItem,
    Payment,
    Product,
    ProductVariant,
)
from .payments import charge


class CartError(ValueError):
    """Raised when a cart change cannot be honoured."""


MAX_QUANTITY_PER_ITEM = 20


def get_or_create_cart(user):
    cart, _ = Cart.objects.get_or_create(user=user)
    return cart


def _validate_quantity(quantity):
    if quantity < 1:
        raise CartError("Quantity must be at least 1.")
    if quantity > MAX_QUANTITY_PER_ITEM:
        raise CartError(f"You can order at most {MAX_QUANTITY_PER_ITEM} of one item.")


@transaction.atomic
def add_to_cart(*, user, product_id, quantity=1, variant_id=None):
    _validate_quantity(quantity)

    try:
        product = Product.objects.get(pk=product_id, is_active=True)
    except Product.DoesNotExist as error:
        raise CartError("This product is no longer available.") from error

    variant = None
    if product.has_variants:
        if variant_id is None:
            raise CartError("Choose an option before adding this to the cart.")
        try:
            # Locked so the stock number cannot change between the check
            # below and the write that follows it.
            variant = ProductVariant.objects.select_for_update().get(
                pk=variant_id,
                product=product,
                is_active=True,
            )
        except ProductVariant.DoesNotExist as error:
            raise CartError("That option is no longer available.") from error
    else:
        if variant_id is not None:
            raise CartError("This product has no options to choose from.")
        # Same lock, on the row that carries the stock in this case.
        product = Product.objects.select_for_update().get(pk=product.pk)

    available = variant.stock if variant else product.stock

    cart = get_or_create_cart(user)
    item = CartItem.objects.filter(
        cart=cart, product=product, variant=variant
    ).first()
    # Adding something already in the cart raises its quantity.
    requested = quantity + (item.quantity if item else 0)

    if available < 1:
        raise CartError("This is out of stock.")
    if requested > available:
        raise CartError(
            f"Only {available} left in stock."
            if item is None
            else f"You already have {item.quantity} in your cart and only "
            f"{available} are in stock."
        )
    _validate_quantity(requested)

    if item is None:
        item = CartItem.objects.create(
            cart=cart,
            product=product,
            variant=variant,
            quantity=quantity,
        )
    else:
        item.quantity = requested
        item.save(update_fields=("quantity", "updated_at"))

    return item


@transaction.atomic
def set_cart_item_quantity(*, user, item_id, quantity):
    _validate_quantity(quantity)

    cart = get_or_create_cart(user)
    try:
        item = CartItem.objects.select_related("product", "variant").get(
            cart=cart, pk=item_id
        )
    except CartItem.DoesNotExist as error:
        raise CartError("This item is not in your cart.") from error

    # Whichever row carries the stock is the one to lock.
    if item.variant_id is not None:
        locked = ProductVariant.objects.select_for_update().get(pk=item.variant_id)
    else:
        locked = Product.objects.select_for_update().get(pk=item.product_id)

    if quantity > locked.stock:
        raise CartError(f"Only {locked.stock} left in stock.")

    item.quantity = quantity
    item.save(update_fields=("quantity", "updated_at"))
    return item


@transaction.atomic
def remove_cart_item(*, user, item_id):
    cart = get_or_create_cart(user)
    deleted, _ = CartItem.objects.filter(cart=cart, pk=item_id).delete()
    if not deleted:
        raise CartError("This item is not in your cart.")


@transaction.atomic
def clear_cart(*, user):
    cart = get_or_create_cart(user)
    CartItem.objects.filter(cart=cart).delete()


class OrderError(ValueError):
    """Something stopped the order; the message is shown to the shopper."""


def _lock_stock_rows(items):
    """
    Locks whichever row carries the stock for each line.

    A variant owns its own stock; a plain product owns its own. Locking
    them before checking is what stops two shoppers buying the same last
    unit at the same moment.
    """
    variant_ids = [item.variant_id for item in items if item.variant_id]
    product_ids = [item.product_id for item in items if not item.variant_id]

    variants = {
        variant.pk: variant
        for variant in ProductVariant.objects.select_for_update().filter(
            pk__in=variant_ids
        )
    }
    products = {
        product.pk: product
        for product in Product.objects.select_for_update().filter(
            pk__in=product_ids
        )
    }
    return variants, products


def _stock_holder(item, variants, products):
    """Whichever row carries this line's stock, plus a name for errors."""
    if item.variant_id:
        return (
            variants.get(item.variant_id),
            f"{item.product.name} ({item.variant.option_label})",
        )
    return products.get(item.product_id), item.product.name


@transaction.atomic
def _open_pending_order(*, user, cart, items, address, payment_method,
                        idempotency_key):
    """
    Writes the intent to buy, before any money moves.

    Its own transaction so that it survives a declined card: the shopper
    needs the order to still be there to retry against, and the failed
    attempt needs something to hang off.
    """
    variants, products = _lock_stock_rows(items)

    # Checked before anything is created, so an obviously impossible order
    # never reaches the card at all.
    for item in items:
        holder, label = _stock_holder(item, variants, products)
        if holder is None:
            raise OrderError(f"{label} is no longer for sale.")
        if holder.stock < item.quantity:
            raise OrderError(
                f"{label}: only {holder.stock} left, you asked for "
                f"{item.quantity}."
            )

    order = Order.objects.create(
        user=user,
        status=Order.Status.PENDING,
        subtotal=cart.subtotal,
        shipping=cart.shipping,
        total=cart.total,
        recipient_name=address.recipient_name,
        phone_number=address.phone_number,
        address_line_1=address.address_line_1,
        address_line_2=address.address_line_2,
        district=address.district,
        city=address.city,
        postal_code=address.postal_code,
        country_code=address.country_code,
        card_brand=payment_method.brand,
        card_last4=payment_method.last4,
        idempotency_key=idempotency_key,
    )

    for item in items:
        seller = item.product.seller
        OrderItem.objects.create(
            order=order,
            product=item.product,
            variant=item.variant,
            seller=seller,
            name=item.product.name,
            slug=item.product.slug,
            option_label=item.variant.option_label if item.variant else "",
            seller_name=(
                getattr(seller, "store_name", "") or getattr(seller, "username", "")
                if seller
                else ""
            ),
            image_url=item.image or "",
            unit_price=item.unit_price,
            quantity=item.quantity,
            line_total=item.line_total,
        )

    return order


@transaction.atomic
def _settle_paid_order(*, order, cart):
    """
    Takes the stock and empties the cart, once the money is in.

    The rows are locked and re-checked here rather than trusting the
    check made before the charge: the two are seconds apart, and somebody
    else may have bought the last one in between.
    """
    items = list(cart.items.select_related("product", "variant"))
    variants, products = _lock_stock_rows(items)

    for item in items:
        holder, label = _stock_holder(item, variants, products)
        if holder is None or holder.stock < item.quantity:
            left = 0 if holder is None else holder.stock
            raise OrderError(
                f"{label}: only {left} left by the time the payment went "
                "through. The order was cancelled and nothing was charged."
            )

    for item in items:
        holder, _ = _stock_holder(item, variants, products)
        holder.stock -= item.quantity
        holder.save(update_fields=["stock"])

    order.status = Order.Status.PAID
    order.paid_at = timezone.now()
    order.save(update_fields=["status", "paid_at"])

    cart.items.all().delete()


def place_order(*, user, address, payment_method, idempotency_key=""):
    """
    Turns the shopper's cart into an order and charges the card.

    Returns (order, created). `created` is False when an idempotency key
    matched an order that already exists, which is what a refresh on the
    payment screen looks like.

    The steps are deliberately in separate transactions. A pending order
    is written first and committed; only then is the card charged, and
    only a successful charge takes stock and empties the cart. A decline
    therefore leaves the shop untouched but keeps both the order and the
    reason it failed, so the shopper can try another card.

    Raises OrderError with a message written for the shopper.
    """
    if idempotency_key:
        existing = Order.objects.filter(
            user=user, idempotency_key=idempotency_key
        ).first()
        if existing is not None:
            return existing, False

    cart = get_or_create_cart(user)
    items = list(
        cart.items.select_related("product", "variant", "product__seller")
    )
    if not items:
        raise OrderError("Your cart is empty.")

    order = _open_pending_order(
        user=user,
        cart=cart,
        items=items,
        address=address,
        payment_method=payment_method,
        idempotency_key=idempotency_key,
    )

    result = charge(
        amount=order.total,
        brand=payment_method.brand,
        last4=payment_method.last4,
    )

    Payment.objects.create(
        order=order,
        status=(
            Payment.Status.SUCCEEDED if result.succeeded else Payment.Status.FAILED
        ),
        amount=order.total,
        currency=order.currency,
        card_brand=payment_method.brand,
        card_last4=payment_method.last4,
        reference=result.reference,
        failure_reason=result.failure_reason,
    )

    if not result.succeeded:
        raise OrderError(result.failure_reason or "The payment was declined.")

    try:
        _settle_paid_order(order=order, cart=cart)
    except OrderError:
        # Charged but unfulfillable. Rare, and the honest thing is to close
        # the order rather than leave it hanging as paid-but-unshipped.
        order.status = Order.Status.CANCELLED
        order.cancelled_at = timezone.now()
        order.save(update_fields=["status", "cancelled_at"])
        raise

    return order, True


@transaction.atomic
def cancel_order(*, user, order):
    """
    Cancels the whole order and puts the stock back.

    All or nothing: one seller posting their parcel closes it for every
    line, which is what `is_cancellable` reports.
    """
    order = Order.objects.select_for_update().get(pk=order.pk, user=user)

    if order.status == Order.Status.CANCELLED:
        raise OrderError("This order is already cancelled.")
    if not order.is_cancellable:
        if order.items.filter(shipped_at__isnull=False).exists():
            raise OrderError(
                "Part of this order has already been shipped, so it can no "
                "longer be cancelled."
            )
        raise OrderError("This order can no longer be cancelled.")

    items = list(order.items.all())
    variants, products = _lock_stock_rows(items)

    for item in items:
        holder = (
            variants.get(item.variant_id)
            if item.variant_id
            else products.get(item.product_id)
        )
        # The product may have been deleted since; there is nothing to
        # give back to in that case.
        if holder is None:
            continue
        holder.stock += item.quantity
        holder.save(update_fields=["stock"])

    order.status = Order.Status.CANCELLED
    order.cancelled_at = timezone.now()
    order.save(update_fields=["status", "cancelled_at"])
    return order


@transaction.atomic
def mark_seller_lines_shipped(*, seller, order):
    """Posts this seller's parcel; other sellers' lines are untouched."""
    lines = order.items.filter(seller=seller, shipped_at__isnull=True)
    if not lines.exists():
        raise OrderError("You have nothing left to ship on this order.")
    if order.status not in {Order.Status.PAID, Order.Status.SHIPPED}:
        raise OrderError("This order is not ready to be shipped.")

    lines.update(shipped_at=timezone.now())
    order.refresh_from_db()
    order.refresh_shipping_status()
    return order


@transaction.atomic
def mark_delivered(*, user, order):
    """The shopper confirming the parcel arrived."""
    order = Order.objects.select_for_update().get(pk=order.pk, user=user)

    if order.status != Order.Status.SHIPPED:
        raise OrderError("This order has not been shipped yet.")

    order.status = Order.Status.DELIVERED
    order.delivered_at = timezone.now()
    order.save(update_fields=["status", "delivered_at"])
    return order
