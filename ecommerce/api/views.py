from decimal import Decimal, InvalidOperation

from django.db.models import Count, Max, Min, Q
from rest_framework import generics
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from ..models import Attribute, Category, Product
from .permissions import IsSeller
from .serializers import (
    AttributeSerializer,
    CategorySerializer,
    ProductSerializer,
    SellerProductSerializer,
)


# Whitelist: the query string may only pick from these, never pass a raw
# column name through to order_by().
SORT_OPTIONS = {
    "newest": "-created_at",
    "price_asc": "price",
    "price_desc": "-price",
    "name": "name",
}


def apply_common_filters(queryset, query_params):
    """Price range, stock and sorting — the controls every store has."""
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

    ordering = SORT_OPTIONS.get(query_params.get("sort", ""), None)
    if ordering:
        queryset = queryset.order_by(ordering)

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

    def get_queryset(self):
        # select_related avoids one extra query per product for the category.
        queryset = Product.objects.filter(is_active=True).select_related("category")

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
    queryset = Product.objects.filter(is_active=True).select_related("category")


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

    Counts respect the category and the search text but ignore the active
    attribute filters. That keeps the other options visible after a
    selection instead of the panel collapsing to a single choice.
    """

    permission_classes = [AllowAny]

    def get(self, request):
        category = request.query_params.get("category", "").strip()
        search = request.query_params.get("q", "").strip()

        # Price bounds come from the products actually on offer, so the
        # range inputs can show real numbers instead of guesses.
        products = Product.objects.filter(is_active=True)
        if category:
            products = products.filter(category__slug=category)
        if search:
            products = products.filter(
                Q(name__icontains=search) | Q(description__icontains=search)
            )
        bounds = products.aggregate(low=Min("price"), high=Max("price"))

        price = {
            "min": str(bounds["low"]) if bounds["low"] is not None else "",
            "max": str(bounds["high"]) if bounds["high"] is not None else "",
        }

        # Attribute facets only make sense inside a category: "Series" has
        # no meaning across shoes and graphics cards at once.
        if not category:
            return Response({"attributes": [], "price": price})

        attributes = Attribute.objects.prefetch_related("values").filter(
            categories__slug=category
        ).distinct()

        product_filter = Q(products__is_active=True)
        if category:
            product_filter &= Q(products__category__slug=category)
        if search:
            product_filter &= Q(products__name__icontains=search) | Q(
                products__description__icontains=search
            )

        payload = []
        for attribute in attributes:
            values = (
                attribute.values.annotate(
                    product_count=Count("products", filter=product_filter, distinct=True)
                )
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

        return Response({"attributes": payload, "price": price})


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
