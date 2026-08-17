"""
Cart operations.

Every write locks the product row it touches. Two shoppers racing for the
last unit is the normal case in a store, not an edge case, and the check
and the write have to happen together for the answer to mean anything.
"""

from django.db import transaction

from .models import Cart, CartItem, Product, ProductVariant


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
