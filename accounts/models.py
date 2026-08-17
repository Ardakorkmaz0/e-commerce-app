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
