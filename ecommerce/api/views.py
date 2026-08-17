from decimal import Decimal, InvalidOperation

from django.contrib.auth import get_user_model
from django.db.models import Avg, Count, Max, Min, Q
from django.shortcuts import get_object_or_404
from rest_framework import generics, status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import Attribute, Category, Product, SellerRating
from .pagination import ProductPagination
from .permissions import SELLER_GROUP, IsSeller
from .serializers import (
    AttributeSerializer,
    CategorySerializer,
    ProductSerializer,
    SellerRatingInputSerializer,
    SellerProductSerializer,
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
        raw = query_params.get(attribute.slug, "").strip()
        if not raw:
            continue

        slugs = [slug.strip() for slug in raw.split(",") if slug.strip()]
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
            .prefetch_related("seller__seller_ratings_received")
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
        .prefetch_related("seller__seller_ratings_received")
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
