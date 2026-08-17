from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.db.models import Q


class User(AbstractUser):
    email = models.EmailField(unique=True)
    store_name = models.CharField(max_length=120, blank=True)
    is_verified_seller = models.BooleanField(default=False)

    @property
    def seller_display_name(self):
        return self.store_name or self.get_full_name() or self.username

    def __str__(self):
        return self.email or self.username


class DeliveryAddress(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="delivery_addresses",
    )
    label = models.CharField(max_length=50)
    recipient_name = models.CharField(max_length=120)
    phone_number = models.CharField(max_length=32)
    address_line_1 = models.CharField(max_length=200)
    address_line_2 = models.CharField(max_length=200, blank=True)
    district = models.CharField(max_length=100)
    city = models.CharField(max_length=100)
    postal_code = models.CharField(max_length=20, blank=True)
    country_code = models.CharField(max_length=2, default="TR")
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-is_default", "-updated_at", "-id")
        constraints = [
            models.UniqueConstraint(
                fields=("user",),
                condition=Q(is_default=True),
                name="uniq_default_delivery_address",
            ),
        ]

    def __str__(self):
        return f"{self.label} - {self.recipient_name}"


class PaymentMethod(models.Model):
    """
    A saved card, stored the way a real store stores one.

    There is deliberately no field for the card number or the security code.
    The number is seen once, while the request is validated, and only what
    is safe to keep survives: the brand, the last four digits, the expiry,
    and a token that stands in for the payment provider's own reference.
    Holding a full card number would put this database in PCI DSS scope.
    """

    VISA = "visa"
    MASTERCARD = "mastercard"
    BRAND_CHOICES = [(VISA, "Visa"), (MASTERCARD, "Mastercard")]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="payment_methods",
    )
    brand = models.CharField(max_length=20, choices=BRAND_CHOICES)
    last4 = models.CharField(max_length=4)
    exp_month = models.PositiveSmallIntegerField()
    exp_year = models.PositiveSmallIntegerField()
    holder_name = models.CharField(max_length=120)

    # Stand-in for the reference a payment provider would hand back. Real
    # charges would be made against this, never against a stored number.
    provider_token = models.CharField(max_length=64, unique=True)

    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-is_default", "-updated_at", "-id")
        constraints = [
            models.UniqueConstraint(
                fields=("user",),
                condition=Q(is_default=True),
                name="uniq_default_payment_method",
            ),
        ]

    def __str__(self):
        return f"{self.get_brand_display()} ····{self.last4}"

    @property
    def is_expired(self):
        from datetime import date

        today = date.today()
        return (self.exp_year, self.exp_month) < (today.year, today.month)
