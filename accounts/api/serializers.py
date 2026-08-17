import re

from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import IntegrityError, transaction
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from accounts.models import DeliveryAddress


User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
        style={"input_type": "password"},
    )
    password_confirm = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
        style={"input_type": "password"},
    )

    class Meta:
        model = User
        fields = (
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "password",
            "password_confirm",
        )
        read_only_fields = ("id",)
        extra_kwargs = {
            "email": {"required": True},
            "first_name": {"required": False},
            "last_name": {"required": False},
        }

    def validate_username(self, value):
        username = value.strip()

        if User.objects.filter(username__iexact=username).exists():
            raise serializers.ValidationError("A user with this username already exists.")

        return username

    def validate_email(self, value):
        email = value.strip().lower()

        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError("A user with this email already exists.")

        return email

    def validate(self, attrs):
        password = attrs.get("password")
        password_confirm = attrs.pop("password_confirm", None)

        if password != password_confirm:
            raise serializers.ValidationError(
                {"password_confirm": "Passwords do not match."}
            )

        user = User(
            username=attrs.get("username"),
            email=attrs.get("email"),
            first_name=attrs.get("first_name", ""),
            last_name=attrs.get("last_name", ""),
        )
        try:
            validate_password(password, user=user)
        except DjangoValidationError as error:
            raise serializers.ValidationError({"password": error.messages}) from error

        return attrs

    def create(self, validated_data):
        try:
            with transaction.atomic():
                return User.objects.create_user(**validated_data)
        except IntegrityError as error:
            raise serializers.ValidationError(
                "A user with this username or email already exists."
            ) from error


class CurrentUserSerializer(serializers.ModelSerializer):
    # Lets the storefront decide whether to show the seller panel link.
    is_seller = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "store_name",
            "is_verified_seller",
            "is_staff",
            "is_seller",
        )
        read_only_fields = fields

    def get_is_seller(self, obj):
        return obj.groups.filter(name="Sellers").exists()


class UpdateCurrentUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("email", "first_name", "last_name", "store_name")

    def validate_email(self, value):
        email = value.strip().lower()
        if User.objects.filter(email__iexact=email).exclude(pk=self.instance.pk).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return email

    def validate_store_name(self, value):
        name = value.strip()
        if name and not self.instance.groups.filter(name="Sellers").exists():
            raise serializers.ValidationError(
                "Only seller accounts can set a store name."
            )
        return name


class DeliveryAddressSerializer(serializers.ModelSerializer):
    required_text_fields = (
        "label",
        "recipient_name",
        "address_line_1",
        "district",
        "city",
    )

    class Meta:
        model = DeliveryAddress
        fields = (
            "id",
            "label",
            "recipient_name",
            "phone_number",
            "address_line_1",
            "address_line_2",
            "district",
            "city",
            "postal_code",
            "country_code",
            "is_default",
            "created_at",
            "updated_at",
        )
        read_only_fields = ("id", "created_at", "updated_at")

    def validate_phone_number(self, value):
        phone_number = value.strip()
        if not re.fullmatch(r"\+?[0-9 ()-]+", phone_number):
            raise serializers.ValidationError(
                "Enter a valid phone number using digits and +, spaces, parentheses, or hyphens."
            )

        digit_count = sum(character.isdigit() for character in phone_number)
        if not 7 <= digit_count <= 15:
            raise serializers.ValidationError(
                "A phone number must contain between 7 and 15 digits."
            )
        return phone_number

    def validate_postal_code(self, value):
        postal_code = value.strip()
        if postal_code and not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9 -]*", postal_code):
            raise serializers.ValidationError(
                "Enter a valid postal code using letters, digits, spaces, or hyphens."
            )
        return postal_code

    def validate_country_code(self, value):
        country_code = value.strip().upper()
        if not re.fullmatch(r"[A-Z]{2}", country_code):
            raise serializers.ValidationError(
                "Enter a two-letter ISO country code."
            )
        return country_code

    def validate(self, attrs):
        errors = {}
        optional_text_fields = ("address_line_2",)

        for field in (*self.required_text_fields, *optional_text_fields):
            if field not in attrs:
                continue
            attrs[field] = attrs[field].strip()
            if field in self.required_text_fields and not attrs[field]:
                errors[field] = "This field may not be blank."

        if errors:
            raise serializers.ValidationError(errors)
        return attrs
