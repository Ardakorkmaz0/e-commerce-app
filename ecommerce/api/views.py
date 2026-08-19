from decimal import Decimal, InvalidOperation
from itertools import product as cartesian_product

from django.contrib.auth import get_user_model
from django.db.models import Avg, Count, Max, Min, Q
from django.shortcuts import get_object_or_404
from django.utils.text import slugify
from rest_framework import generics, status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import DeliveryAddress, PaymentMethod

from ..models import (
    Attribute,
    AttributeValue,
    Category,
    Order,
    Product,
    ProductImage,
    ProductVariant,
    SellerRating,
)
from ..services import (
    CartError,
    OrderError,
    add_to_cart,
    cancel_order,
    clear_cart,
    get_or_create_cart,
    mark_delivered,
    mark_seller_lines_shipped,
    place_order,
    remove_cart_item,
    set_cart_item_quantity,
)
from .pagination import ProductPagination
from .permissions import SELLER_GROUP, IsSeller, IsVariantOwner
from .serializers import (
    AddToCartSerializer,
    AttributeSerializer,
    CartSerializer,
    CategorySerializer,
    OrderSerializer,
    PlaceOrderSerializer,
    ProductSerializer,
    SellerOrderSerializer,
    SellerRatingInputSerializer,
    SellerOptionSerializer,
    SellerProductImageSerializer,
    SellerProductSerializer,
    SellerVariantSerializer,
    VariantGenerateSerializer,
    UpdateCartItemSerializer,
)


User = get_user_model()


# Whitelist: the query string may only pick from these, never pass a raw
# column name through to order_by().
SORT_OPTIONS = {
    "newest": ("-created_at", "-id"),
    "oldest": ("created_at", "id"),
    "price_asc": ("price", "id"),
    "price_desc": ("-price", "-id"),
    "name": ("name", "id"),
    "stock_desc": ("-stock", "id"),
}

PRICE_RANGES = {
    "under-50": {"label": "Under $50", "min": None, "max": Decimal("50")},
    "50-100": {
        "label": "$50 to $100",
        "min": Decimal("50"),
        "max": Decimal("100"),
    },
    "100-250": {
        "label": "$100 to $250",
        "min": Decimal("100"),
        "max": Decimal("250"),
    },
    "250-500": {
        "label": "$250 to $500",
        "min": Decimal("250"),
        "max": Decimal("500"),
    },
    "over-500": {
        "label": "$500 and over",
        "min": Decimal("500"),
        "max": None,
    },
}


def apply_common_filters(queryset, query_params):
    """Price range, stock and sorting — the controls every store has."""
    selected_range = PRICE_RANGES.get(query_params.get("price_range", ""))
    if selected_range:
        if selected_range["min"] is not None:
            queryset = queryset.filter(price__gte=selected_range["min"])
        if selected_range["max"] is not None:
            queryset = queryset.filter(price__lt=selected_range["max"])

    min_price = query_params.get("min_price", "").strip()
    if min_price:
        try:
            queryset = queryset.filter(price__gte=Decimal(min_price))
        except (InvalidOperation, ValueError):
            pass  # A malformed number is ignored rather than erroring.

    max_price = query_params.get("max_price", "").strip()
    if max_price:
        try:
            queryset = queryset.filter(price__lte=Decimal(max_price))
        except (InvalidOperation, ValueError):
            pass

    if query_params.get("in_stock") == "1":
        queryset = queryset.filter(stock__gt=0)

    availability = query_params.get("availability", "")
    if availability == "in_stock":
        queryset = queryset.filter(stock__gt=0)
    elif availability == "low_stock":
        queryset = queryset.filter(stock__range=(1, 10))
    elif availability == "out_of_stock":
        queryset = queryset.filter(stock=0)

    ordering = SORT_OPTIONS.get(query_params.get("sort", ""), SORT_OPTIONS["newest"])
    queryset = queryset.order_by(*ordering)

    return queryset


def apply_attribute_filters(queryset, query_params, attributes):
    """
    Narrows a product queryset by the attribute filters in the query string.

    Each attribute is its own parameter, and commas separate alternatives:

        ?marka=rtx,amd&seri=3060

    Values of the same attribute are OR-ed (RTX *or* AMD) while different
    attributes are AND-ed (a brand *and* a series). That is what a shopper
    expects, and it falls out of calling .filter() once per attribute:
    each call adds a separate join, so a product must satisfy all of them.
    """
    for attribute in attributes:
        # Two shapes reach this: the desktop panel builds comma separated
        # links (?brand=rtx,amd) while an HTML form repeats the key
        # (?brand=rtx&brand=amd). Accept both.
        raw_values = (
            query_params.getlist(attribute.slug)
            if hasattr(query_params, "getlist")
            else [query_params.get(attribute.slug, "")]
        )

        slugs = [
            slug.strip()
            for raw in raw_values
            for slug in raw.split(",")
            if slug.strip()
        ]
        if not slugs:
            continue

        queryset = queryset.filter(
            attribute_values__attribute=attribute,
            attribute_values__slug__in=slugs,
        )

    # Several joins can return the same product more than once.
    return queryset.distinct()


class CategoryListView(generics.ListAPIView):
    """GET /api/v1/categories/ — the product catalog is public."""

    permission_classes = [AllowAny]
    serializer_class = CategorySerializer
    queryset = Category.objects.all()


class ProductListView(generics.ListAPIView):
    """
    GET /api/v1/products/

    Query parameters:
      ?category=<slug>  filter by category
      ?q=<text>         search in name and description
    """

    permission_classes = [AllowAny]
    serializer_class = ProductSerializer
    pagination_class = ProductPagination

    def get_queryset(self):
        # select_related avoids one extra query per product for the category.
        queryset = (
            Product.objects.filter(is_active=True)
            .select_related("category", "seller")
            .prefetch_related(
                "seller__seller_ratings_received",
                # Without this the variant pickers cost one query per option.
                "variants__option_values__attribute",
            )
        )

        category = self.request.query_params.get("category", "").strip()
        if category:
            queryset = queryset.filter(category__slug=category)

        search = self.request.query_params.get("q", "").strip()
        if search:
            queryset = queryset.filter(
                Q(name__icontains=search) | Q(description__icontains=search)
            )

        # Only attributes belonging to the selected category can filter, so
        # a stray ?renk=siyah on graphics cards is ignored rather than
        # silently emptying the list.
        attributes = Attribute.objects.all()
        if category:
            attributes = attributes.filter(categories__slug=category)
        queryset = apply_attribute_filters(
            queryset, self.request.query_params, attributes
        )

        return apply_common_filters(queryset, self.request.query_params)


class ProductDetailView(generics.RetrieveAPIView):
    """GET /api/v1/products/<slug>/"""

    permission_classes = [AllowAny]
    serializer_class = ProductSerializer
    lookup_field = "slug"
    queryset = (
        Product.objects.filter(is_active=True)
        .select_related("category", "seller")
        .prefetch_related(
            "seller__seller_ratings_received",
            # Without this the variant pickers cost one query per option.
            "variants__option_values__attribute",
        )
    )


def seller_rating_payload(seller, customer):
    """Return the current customer's score together with public statistics."""
    current_score = SellerRating.objects.filter(
        seller=seller,
        customer=customer,
    ).values_list("score", flat=True).first()
    statistics = SellerRating.objects.filter(seller=seller).aggregate(
        average=Avg("score"),
        count=Count("id"),
    )
    average = statistics["average"]

    return {
        "seller_id": seller.pk,
        "score": current_score,
        "rating": round(float(average), 1) if average is not None else None,
        "rating_count": statistics["count"],
    }


class SellerRatingView(APIView):
    """
    GET / PUT / DELETE /api/v1/sellers/<id>/rating/

    The URL represents the authenticated customer's single rating for one
    seller. PUT is an idempotent upsert and DELETE is idempotent as well.
    """

    permission_classes = [IsAuthenticated]

    def get_seller(self, seller_id):
        return get_object_or_404(
            User.objects.filter(
                is_active=True,
                groups__name=SELLER_GROUP,
            ).distinct(),
            pk=seller_id,
        )

    def get(self, request, seller_id):
        seller = self.get_seller(seller_id)
        return Response(seller_rating_payload(seller, request.user))

    def put(self, request, seller_id):
        seller = self.get_seller(seller_id)
        if seller.pk == request.user.pk:
            return Response(
                {"detail": "You cannot rate yourself."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = SellerRatingInputSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        SellerRating.objects.update_or_create(
            seller=seller,
            customer=request.user,
            defaults={"score": serializer.validated_data["score"]},
        )
        return Response(seller_rating_payload(seller, request.user))

    def delete(self, request, seller_id):
        seller = self.get_seller(seller_id)
        SellerRating.objects.filter(
            seller=seller,
            customer=request.user,
        ).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class AttributeListView(generics.ListAPIView):
    """
    GET /api/v1/attributes/

    Every attribute with its values and the categories it belongs to. The
    seller form loads this once and narrows the choices in the browser as
    the seller picks a category.
    """

    permission_classes = [AllowAny]
    serializer_class = AttributeSerializer
    queryset = Attribute.objects.prefetch_related("values", "categories")


class FacetListView(APIView):
    """
    GET /api/v1/facets/?category=<slug>&q=<text>

    Describes the filter panel: which attributes apply to the selected
    category, their values, and how many products each value would match.

    Attribute counts respect every active filter except the group's own
    selection, so choosing a product type narrows the groups below it and
    values that can no longer match disappear. See the loop below for why
    a group is excluded from its own count.
    """

    permission_classes = [AllowAny]

    def get(self, request):
        category = request.query_params.get("category", "").strip()
        search = request.query_params.get("q", "").strip()

        base_products = Product.objects.filter(is_active=True)
        if search:
            base_products = base_products.filter(
                Q(name__icontains=search) | Q(description__icontains=search)
            )

        category_rows = (
            base_products.values("category__name", "category__slug")
            .annotate(product_count=Count("id"))
            .order_by("category__name")
        )
        categories = [
            {
                "name": row["category__name"],
                "slug": row["category__slug"],
                "count": row["product_count"],
            }
            for row in category_rows
        ]

        products = base_products
        if category:
            products = products.filter(category__slug=category)

        bounds = products.aggregate(low=Min("price"), high=Max("price"))

        price_ranges = []
        for slug, definition in PRICE_RANGES.items():
            range_products = products
            if definition["min"] is not None:
                range_products = range_products.filter(price__gte=definition["min"])
            if definition["max"] is not None:
                range_products = range_products.filter(price__lt=definition["max"])
            price_ranges.append(
                {
                    "slug": slug,
                    "label": definition["label"],
                    "count": range_products.count(),
                }
            )

        price = {
            "min": str(bounds["low"]) if bounds["low"] is not None else "",
            "max": str(bounds["high"]) if bounds["high"] is not None else "",
            "ranges": price_ranges,
        }

        common_payload = {
            "categories": categories,
            "availability": {
                "in_stock": products.filter(stock__gt=0).count(),
                "low_stock": products.filter(stock__range=(1, 10)).count(),
                "out_of_stock": products.filter(stock=0).count(),
            },
            "price": price,
        }

        # Attribute facets only make sense inside a category: "Series" has
        # no meaning across shoes and graphics cards at once.
        if not category:
            return Response({**common_payload, "attributes": []})

        attributes = Attribute.objects.prefetch_related("values").filter(
            categories__slug=category
        ).distinct()

        attributes = list(attributes)

        payload = []
        for attribute in attributes:
            # Count against everything already chosen, except this
            # attribute's own selection.
            #
            # Excluding self is what makes multi-select work: values inside
            # one group are OR-ed, so if picking "Headphones" also narrowed
            # the Product type group, its siblings would drop to zero and a
            # second type could never be added. Every *other* group does
            # narrow, which is the behaviour being asked for here — after
            # choosing Headphones, Connectivity only lists what headphones
            # actually have.
            others = [item for item in attributes if item.pk != attribute.pk]
            narrowed = apply_attribute_filters(
                products, request.query_params, others
            )
            narrowed = apply_common_filters(narrowed, request.query_params)
            # No ORDER BY inside the subquery below; it would be dead work.
            narrowed = narrowed.order_by()

            # filter() before annotate() makes Count run over the narrowed
            # relation instead of every product attached to the value.
            values = (
                attribute.values.filter(products__in=narrowed)
                .annotate(product_count=Count("products", distinct=True))
                .filter(product_count__gt=0)
                .order_by("position", "name")
            )

            if not values:
                continue

            payload.append(
                {
                    "name": attribute.name,
                    "slug": attribute.slug,
                    "values": [
                        {
                            "name": value.name,
                            "slug": value.slug,
                            "count": value.product_count,
                        }
                        for value in values
                    ],
                }
            )

        return Response({**common_payload, "attributes": payload})


# ── Seller panel ─────────────────────────────────────────────────────
# These endpoints back the storefront's seller pages. They require a JWT
# and Sellers group membership, never Django admin access.


class SellerProductListCreateView(generics.ListCreateAPIView):
    """
    GET  /api/v1/seller/products/   the seller's own listings
    POST /api/v1/seller/products/   create a listing
    """

    permission_classes = [IsSeller]
    serializer_class = SellerProductSerializer

    def get_queryset(self):
        # Inactive products are included: the seller manages them too.
        return (
            Product.objects.filter(seller=self.request.user)
            .select_related("category")
            .order_by("-created_at")
        )

    def perform_create(self, serializer):
        # Ownership comes from the token, never from the request body.
        serializer.save(seller=self.request.user)


class SellerProductDetailView(generics.RetrieveUpdateDestroyAPIView):
    """GET / PATCH / DELETE /api/v1/seller/products/<slug>/"""

    permission_classes = [IsSeller]
    serializer_class = SellerProductSerializer
    lookup_field = "slug"

    def get_queryset(self):
        # Filtering here means another seller's slug simply 404s.
        return Product.objects.filter(seller=self.request.user).select_related(
            "category"
        )


class SellerVariantMixin:
    """Resolves the product from the URL and proves the seller owns it."""

    permission_classes = [IsVariantOwner]
    serializer_class = SellerVariantSerializer

    def get_product(self):
        # Filtering by owner means another seller's slug simply 404s.
        return get_object_or_404(
            Product.objects.select_related("category"),
            slug=self.kwargs["slug"],
            seller=self.request.user,
        )

    def get_serializer_context(self):
        context = super().get_serializer_context()
        # The serializer validates options against the product's category,
        # so it needs the product the URL points at.
        context["product"] = self.get_product()
        return context

    def get_queryset(self):
        return (
            ProductVariant.objects.filter(product=self.get_product())
            .prefetch_related("option_values__attribute")
            .order_by("position", "id")
        )


class SellerVariantListCreateView(SellerVariantMixin, generics.ListCreateAPIView):
    """
    GET  /api/v1/seller/products/<slug>/variants/
    POST /api/v1/seller/products/<slug>/variants/
    """

    def perform_create(self, serializer):
        serializer.save(product=self.get_product())


class SellerVariantDetailView(
    SellerVariantMixin, generics.RetrieveUpdateDestroyAPIView
):
    """GET / PATCH / DELETE /api/v1/seller/products/<slug>/variants/<id>/"""


class SellerVariantGenerateView(SellerVariantMixin, APIView):
    """
    POST /api/v1/seller/products/<slug>/variants/generate/

    Takes the values the seller ticked and creates every combination that
    does not exist yet, so nobody has to enter "White / 1 TB", "White /
    2 TB", "Black / 1 TB"… by hand. Existing rows are left alone, which
    makes the call safe to repeat after adding one more colour.
    """

    def post(self, request, slug):
        product = self.get_product()

        serializer = VariantGenerateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        values = serializer.validated_data["value_ids"]

        if not values:
            raise ValidationError({"value_ids": ["Pick at least one option."]})

        allowed = set(
            Attribute.objects.filter(categories=product.category).values_list(
                "id", flat=True
            )
        )
        stray = [value.name for value in values if value.attribute_id not in allowed]
        if stray:
            raise ValidationError(
                {
                    "value_ids": [
                        f"These do not apply to {product.category.name}: "
                        + ", ".join(stray)
                    ]
                }
            )

        # One bucket per attribute, ordered so the generated rows read in
        # the same order as the filter panel.
        buckets = {}
        for value in sorted(
            values,
            key=lambda v: (v.attribute.position, v.attribute.name, v.position, v.name),
        ):
            buckets.setdefault(value.attribute_id, []).append(value)

        combinations = list(cartesian_product(*buckets.values()))
        if len(combinations) > 100:
            raise ValidationError(
                {
                    "value_ids": [
                        f"That would create {len(combinations)} variants. "
                        "Keep it under 100."
                    ]
                }
            )

        existing = {
            frozenset(variant.option_values.values_list("pk", flat=True))
            for variant in product.variants.prefetch_related("option_values")
        }

        position = product.variants.count()
        created = []
        for combination in combinations:
            key = frozenset(value.pk for value in combination)
            if key in existing:
                continue

            variant = ProductVariant.objects.create(product=product, position=position)
            variant.option_values.set(combination)
            created.append(variant)
            position += 1

        return Response(
            {
                "created": len(created),
                "skipped": len(combinations) - len(created),
                "variants": SellerVariantSerializer(
                    self.get_queryset(), many=True, context={"request": request}
                ).data,
            },
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class SellerOptionCreateView(SellerVariantMixin, APIView):
    """
    POST /api/v1/seller/products/<slug>/options/

    Adds one option value, creating its group first when the seller typed a
    new one. Attributes and their values are shared taxonomy — the same
    "Colour: Red" filters the whole catalog — so a name that already exists
    is reused rather than duplicated.
    """

    def post(self, request, slug):
        product = self.get_product()

        serializer = SellerOptionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        attribute_id = data.get("attribute_id")
        if attribute_id:
            attribute = Attribute.objects.filter(
                pk=attribute_id, categories=product.category
            ).first()
            if attribute is None:
                raise ValidationError(
                    {"attribute_id": ["That option group is not on this category."]}
                )
        else:
            name = data["attribute_name"].strip()
            # Attribute names are unique across the shop, so reuse the row
            # and just attach it to this category.
            attribute, _ = Attribute.objects.get_or_create(
                name__iexact=name,
                defaults={"name": name, "position": Attribute.objects.count() + 1},
            )
            attribute.categories.add(product.category)

        slug_value = slugify(data["name"])
        value = attribute.values.filter(slug=slug_value).first()
        created = value is None

        if created:
            value = AttributeValue.objects.create(
                attribute=attribute,
                name=data["name"],
                swatch_color=data.get("swatch_color", ""),
                position=attribute.values.count() + 1,
            )
        elif data.get("swatch_color") and not value.swatch_color:
            # Filling in a colour that was missing is an improvement, not a
            # rename, so it is safe to apply to the shared row.
            value.swatch_color = data["swatch_color"]
            value.save(update_fields=["swatch_color"])

        return Response(
            {
                "created": created,
                "attribute": {"id": attribute.pk, "name": attribute.name},
                "value": {
                    "id": value.pk,
                    "name": value.name,
                    "slug": value.slug,
                    "swatch_color": value.swatch_color,
                },
            },
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class SellerImageMixin(SellerVariantMixin):
    """Same ownership rule, over the product's gallery."""

    serializer_class = SellerProductImageSerializer

    def get_queryset(self):
        return ProductImage.objects.filter(
            product=self.get_product()
        ).order_by("position", "id")


class SellerImageListCreateView(SellerImageMixin, generics.ListCreateAPIView):
    """
    GET  /api/v1/seller/products/<slug>/images/
    POST /api/v1/seller/products/<slug>/images/
    """

    def perform_create(self, serializer):
        product = self.get_product()
        # New photos land at the end of the strip.
        serializer.save(
            product=product,
            position=serializer.validated_data.get(
                "position", product.gallery.count()
            ),
        )


class SellerImageDetailView(SellerImageMixin, generics.RetrieveUpdateDestroyAPIView):
    """GET / PATCH / DELETE /api/v1/seller/products/<slug>/images/<id>/"""


# ── Cart ─────────────────────────────────────────────────────────────
# Quantities and totals are computed on the server. The client sends what
# it wants, never what it thinks the price is.


class CartView(APIView):
    """GET /api/v1/cart/ — the signed-in shopper's cart."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        cart = get_or_create_cart(request.user)
        return Response(
            CartSerializer(cart, context={"request": request}).data
        )

    def delete(self, request):
        clear_cart(user=request.user)
        cart = get_or_create_cart(request.user)
        return Response(
            CartSerializer(cart, context={"request": request}).data
        )


class CartItemsView(APIView):
    """POST /api/v1/cart/items/ — add a product, or raise its quantity."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = AddToCartSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            add_to_cart(
                user=request.user,
                product_id=serializer.validated_data["product_id"],
                variant_id=serializer.validated_data.get("variant_id"),
                quantity=serializer.validated_data["quantity"],
            )
        except CartError as error:
            raise ValidationError({"detail": [str(error)]}) from error

        cart = get_or_create_cart(request.user)
        return Response(
            CartSerializer(cart, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class CartItemDetailView(APIView):
    """PATCH / DELETE /api/v1/cart/items/<id>/"""

    permission_classes = [IsAuthenticated]

    def patch(self, request, item_id):
        serializer = UpdateCartItemSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            set_cart_item_quantity(
                user=request.user,
                item_id=item_id,
                quantity=serializer.validated_data["quantity"],
            )
        except CartError as error:
            raise ValidationError({"detail": [str(error)]}) from error

        cart = get_or_create_cart(request.user)
        return Response(
            CartSerializer(cart, context={"request": request}).data
        )

    def delete(self, request, item_id):
        try:
            remove_cart_item(user=request.user, item_id=item_id)
        except CartError as error:
            raise ValidationError({"detail": [str(error)]}) from error

        cart = get_or_create_cart(request.user)
        return Response(
            CartSerializer(cart, context={"request": request}).data
        )


# ── Orders ───────────────────────────────────────────────────────────
# An order is a copy of what the shopper agreed to, so none of these
# views read prices or names from the catalog.


def _order_queryset(user):
    return (
        Order.objects.filter(user=user)
        .prefetch_related("items", "payments")
        .order_by("-created_at", "-id")
    )


class OrderListCreateView(APIView):
    """
    GET  /api/v1/orders/   the shopper's own orders
    POST /api/v1/orders/   turn the cart into one and charge the card
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        orders = _order_queryset(request.user)
        return Response(
            OrderSerializer(orders, many=True, context={"request": request}).data
        )

    def post(self, request):
        serializer = PlaceOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        address = DeliveryAddress.objects.filter(
            pk=data["address_id"], user=request.user
        ).first()
        if address is None:
            raise ValidationError({"address_id": ["Choose one of your addresses."]})

        card = PaymentMethod.objects.filter(
            pk=data["payment_method_id"], user=request.user
        ).first()
        if card is None:
            raise ValidationError(
                {"payment_method_id": ["Choose one of your saved cards."]}
            )
        if card.is_expired:
            raise ValidationError(
                {"payment_method_id": ["That card has expired."]}
            )

        try:
            order, created = place_order(
                user=request.user,
                address=address,
                payment_method=card,
                idempotency_key=data.get("idempotency_key", ""),
            )
        except OrderError as error:
            # The message is written for the shopper, so it goes straight
            # through rather than being replaced with something generic.
            raise ValidationError({"detail": [str(error)]})

        # A repeat of the same key created nothing, so it is not a 201.
        return Response(
            OrderSerializer(order, context={"request": request}).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class OrderDetailView(APIView):
    """GET /api/v1/orders/<order_number>/"""

    permission_classes = [IsAuthenticated]

    def get_order(self, request, order_number):
        # Filtered by owner, so somebody else's number simply 404s.
        return get_object_or_404(
            _order_queryset(request.user), order_number=order_number
        )

    def get(self, request, order_number):
        order = self.get_order(request, order_number)
        return Response(
            OrderSerializer(order, context={"request": request}).data
        )


class OrderCancelView(OrderDetailView):
    """POST /api/v1/orders/<order_number>/cancel/"""

    def post(self, request, order_number):
        order = self.get_order(request, order_number)
        try:
            order = cancel_order(user=request.user, order=order)
        except OrderError as error:
            raise ValidationError({"detail": [str(error)]})

        return Response(
            OrderSerializer(order, context={"request": request}).data
        )


class OrderDeliveredView(OrderDetailView):
    """POST /api/v1/orders/<order_number>/delivered/"""

    def post(self, request, order_number):
        order = self.get_order(request, order_number)
        try:
            order = mark_delivered(user=request.user, order=order)
        except OrderError as error:
            raise ValidationError({"detail": [str(error)]})

        return Response(
            OrderSerializer(order, context={"request": request}).data
        )


class SellerOrderListView(APIView):
    """
    GET /api/v1/seller/orders/

    Orders that contain something this seller sold, narrowed to their own
    lines. Unpaid ones are left out: nothing to pack until it is paid for.
    """

    permission_classes = [IsSeller]

    def get(self, request):
        orders = (
            Order.objects.filter(
                items__seller=request.user,
                status__in=[
                    Order.Status.PAID,
                    Order.Status.SHIPPED,
                    Order.Status.DELIVERED,
                    Order.Status.CANCELLED,
                ],
            )
            .distinct()
            .prefetch_related("items")
            .order_by("-created_at", "-id")
        )
        return Response(
            SellerOrderSerializer(
                orders,
                many=True,
                context={"request": request, "seller": request.user},
            ).data
        )


class SellerOrderShipView(APIView):
    """POST /api/v1/seller/orders/<order_number>/ship/"""

    permission_classes = [IsSeller]

    def post(self, request, order_number):
        order = get_object_or_404(
            Order.objects.filter(items__seller=request.user).distinct(),
            order_number=order_number,
        )

        try:
            order = mark_seller_lines_shipped(seller=request.user, order=order)
        except OrderError as error:
            raise ValidationError({"detail": [str(error)]})

        return Response(
            SellerOrderSerializer(
                order, context={"request": request, "seller": request.user}
            ).data
        )


