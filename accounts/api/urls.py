from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .views import (
    CurrentUserView,
    DeliveryAddressDetailView,
    DeliveryAddressListCreateView,
    LogoutView,
    PaymentMethodDetailView,
    PaymentMethodListCreateView,
    RegisterView,
)


app_name = "accounts_api"

urlpatterns = [
    path("register/", RegisterView.as_view(), name="register"),
    path("token/", TokenObtainPairView.as_view(), name="token"),
    path("token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("me/", CurrentUserView.as_view(), name="me"),
    path(
        "addresses/",
        DeliveryAddressListCreateView.as_view(),
        name="addresses",
    ),
    path(
        "addresses/<int:address_id>/",
        DeliveryAddressDetailView.as_view(),
        name="address_detail",
    ),
    path(
        "payment-methods/",
        PaymentMethodListCreateView.as_view(),
        name="payment_methods",
    ),
    path(
        "payment-methods/<int:method_id>/",
        PaymentMethodDetailView.as_view(),
        name="payment_method_detail",
    ),
    path("logout/", LogoutView.as_view(), name="logout"),
]
