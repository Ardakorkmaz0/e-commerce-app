from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    email = models.EmailField(unique=True)
    store_name = models.CharField(max_length=120, blank=True)
    is_verified_seller = models.BooleanField(default=False)

    @property
    def seller_display_name(self):
        return self.store_name or self.get_full_name() or self.username

    def __str__(self):
        return self.email or self.username
