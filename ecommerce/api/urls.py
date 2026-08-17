from django.urls import path

from .views import (
    AttributeListView,
    CartItemDetailView,
    CartItemsView,
    CartView,
    CategoryListView,
    FacetListView,
    ProductDetailView,
    ProductListView,
    SellerRatingView,
    SellerProductDetailView,
    SellerProductListCreateView,
)


app_name = "ecommerce_api"

urlpatterns = [
    # Public catalog
    # Cart (JWT required)
    path("cart/", CartView.as_view(), name="cart"),
    path("cart/items/", CartItemsView.as_view(), name="cart_items"),
    path(
        "cart/items/<int:item_id>/",
        CartItemDetailView.as_view(),
        name="cart_item_detail",
    ),
    path("attributes/", AttributeListView.as_view(), name="attributes"),
    path("categories/", CategoryListView.as_view(), name="categories"),
    path("facets/", FacetListView.as_view(), name="facets"),
    path("products/", ProductListView.as_view(), name="products"),
    path("products/<slug:slug>/", ProductDetailView.as_view(), name="product_detail"),
    path(
        "sellers/<int:seller_id>/rating/",
        SellerRatingView.as_view(),
        name="seller_rating",
    ),
    # Seller panel (JWT + Sellers group)
    path(
        "seller/products/",
        SellerProductListCreateView.as_view(),
        name="seller_products",
    ),
    path(
        "seller/products/<slug:slug>/",
        SellerProductDetailView.as_view(),
        name="seller_product_detail",
    ),
]
