from django.contrib.auth import get_user_model
from django.db import transaction

from .models import DeliveryAddress, PaymentMethod


User = get_user_model()
_MISSING = object()


class DefaultAddressRequired(ValueError):
    """Raised when an update would leave a user without a default address."""


def _lock_user(user):
    # Every address mutation locks the same row. This serializes concurrent
    # changes for one user without blocking address changes made by others.
    return User.objects.select_for_update().get(pk=user.pk)


@transaction.atomic
def create_delivery_address(*, user, validated_data):
    locked_user = _lock_user(user)
    data = dict(validated_data)
    requested_default = data.pop("is_default", False)
    addresses = DeliveryAddress.objects.filter(user=locked_user)

    # The first address is always the default. Checking for a default rather
    # than only checking for rows also repairs a legacy set with no default.
    make_default = requested_default or not addresses.filter(is_default=True).exists()
    if make_default:
        addresses.filter(is_default=True).update(is_default=False)

    return DeliveryAddress.objects.create(
        user=locked_user,
        is_default=make_default,
        **data,
    )


@transaction.atomic
def update_delivery_address(*, user, address_id, validated_data):
    locked_user = _lock_user(user)
    address = DeliveryAddress.objects.get(user=locked_user, pk=address_id)
    data = dict(validated_data)
    requested_default = data.pop("is_default", _MISSING)

    if requested_default is True:
        DeliveryAddress.objects.filter(
            user=locked_user,
            is_default=True,
        ).exclude(pk=address.pk).update(is_default=False)
        address.is_default = True
    elif requested_default is False and address.is_default:
        raise DefaultAddressRequired(
            "Select another default address before removing this one."
        )

    for field, value in data.items():
        setattr(address, field, value)

    # Direct database changes made outside this service could leave no default.
    # Make the address being edited the default so the invariant is restored.
    if not DeliveryAddress.objects.filter(
        user=locked_user,
        is_default=True,
    ).exclude(pk=address.pk).exists() and not address.is_default:
        address.is_default = True

    address.save()
    return address


@transaction.atomic
def delete_delivery_address(*, user, address_id):
    locked_user = _lock_user(user)
    address = DeliveryAddress.objects.get(user=locked_user, pk=address_id)
    address.delete()

    remaining = DeliveryAddress.objects.filter(user=locked_user)
    if remaining.exists() and not remaining.filter(is_default=True).exists():
        replacement = remaining.order_by("-updated_at", "-id").first()
        replacement.is_default = True
        replacement.save(update_fields=("is_default", "updated_at"))


# ── Payment methods ──────────────────────────────────────────────────
# Same shape as the address services above: one default per user, kept
# consistent under a row lock.


@transaction.atomic
def create_payment_method(*, user, brand, last4, provider_token, holder_name,
                          exp_month, exp_year, make_default=False):
    """Takes only the tokenised parts — never a card number."""
    locked_user = _lock_user(user)
    methods = PaymentMethod.objects.filter(user=locked_user)

    is_default = make_default or not methods.filter(is_default=True).exists()
    if is_default:
        methods.filter(is_default=True).update(is_default=False)

    return PaymentMethod.objects.create(
        user=locked_user,
        brand=brand,
        last4=last4,
        provider_token=provider_token,
        holder_name=holder_name,
        exp_month=exp_month,
        exp_year=exp_year,
        is_default=is_default,
    )


@transaction.atomic
def set_default_payment_method(*, user, method_id):
    locked_user = _lock_user(user)
    method = PaymentMethod.objects.get(user=locked_user, pk=method_id)

    PaymentMethod.objects.filter(user=locked_user, is_default=True).exclude(
        pk=method.pk
    ).update(is_default=False)

    if not method.is_default:
        method.is_default = True
        method.save(update_fields=("is_default", "updated_at"))

    return method


@transaction.atomic
def delete_payment_method(*, user, method_id):
    locked_user = _lock_user(user)
    method = PaymentMethod.objects.get(user=locked_user, pk=method_id)
    method.delete()

    # Promote another card so the account is never left without a default.
    remaining = PaymentMethod.objects.filter(user=locked_user)
    if remaining.exists() and not remaining.filter(is_default=True).exists():
        replacement = remaining.order_by("-updated_at", "-id").first()
        replacement.is_default = True
        replacement.save(update_fields=("is_default", "updated_at"))
