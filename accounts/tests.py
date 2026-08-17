from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.db import IntegrityError, transaction
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from .models import DeliveryAddress


User = get_user_model()


class RegisterApiTests(APITestCase):
    def setUp(self):
        self.url = reverse("accounts_api:register")
        self.payload = {
            "username": "newcustomer",
            "email": "Customer@Example.com",
            "first_name": "New",
            "last_name": "Customer",
            "password": "StrongPass!2026",
            "password_confirm": "StrongPass!2026",
        }

    def test_registers_user_and_hashes_password(self):
        response = self.client.post(self.url, self.payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        user = User.objects.get(username="newcustomer")
        self.assertEqual(user.email, "customer@example.com")
        self.assertEqual(user.first_name, "New")
        self.assertEqual(user.last_name, "Customer")
        self.assertTrue(user.check_password(self.payload["password"]))
        self.assertNotIn("password", response.data)
        self.assertNotIn("password_confirm", response.data)

    def test_rejects_duplicate_username_case_insensitively(self):
        User.objects.create_user(
            username="NewCustomer",
            email="existing@example.com",
            password="StrongPass!2026",
        )

        response = self.client.post(self.url, self.payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("username", response.data)

    def test_rejects_duplicate_email_case_insensitively(self):
        User.objects.create_user(
            username="existing",
            email="customer@example.com",
            password="StrongPass!2026",
        )

        response = self.client.post(self.url, self.payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("email", response.data)

    def test_rejects_password_mismatch(self):
        self.payload["password_confirm"] = "DifferentPass!2026"

        response = self.client.post(self.url, self.payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("password_confirm", response.data)
        self.assertFalse(User.objects.filter(username="newcustomer").exists())

    def test_rejects_weak_password(self):
        self.payload["password"] = "123"
        self.payload["password_confirm"] = "123"

        response = self.client.post(self.url, self.payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("password", response.data)
        self.assertFalse(User.objects.filter(username="newcustomer").exists())

    def test_does_not_allow_privilege_escalation(self):
        payload = {
            **self.payload,
            "is_staff": True,
            "is_superuser": True,
        }

        response = self.client.post(self.url, payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        user = User.objects.get(username="newcustomer")
        self.assertFalse(user.is_staff)
        self.assertFalse(user.is_superuser)


class AuthenticationApiTests(APITestCase):
    def setUp(self):
        self.password = "StrongPass!2026"
        self.user = User.objects.create_user(
            username="customer",
            email="customer@example.com",
            password=self.password,
        )

    def test_returns_tokens_for_valid_credentials(self):
        response = self.client.post(
            reverse("accounts_api:token"),
            {"username": self.user.username, "password": self.password},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)

    def test_returns_current_user_for_access_token(self):
        access_token = str(RefreshToken.for_user(self.user).access_token)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access_token}")

        response = self.client.get(reverse("accounts_api:me"))

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["username"], self.user.username)
        self.assertEqual(response.data["email"], self.user.email)

    def test_rejects_current_user_without_access_token(self):
        response = self.client.get(reverse("accounts_api:me"))

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_blacklists_refresh_token_on_logout(self):
        refresh_token = RefreshToken.for_user(self.user)

        response = self.client.post(
            reverse("accounts_api:logout"),
            {"refresh": str(refresh_token)},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        refresh_response = self.client.post(
            reverse("accounts_api:token_refresh"),
            {"refresh": str(refresh_token)},
            format="json",
        )
        self.assertEqual(refresh_response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_seller_can_update_store_name_but_not_verification(self):
        self.user.groups.add(Group.objects.create(name="Sellers"))
        self.client.force_authenticate(user=self.user)

        response = self.client.patch(
            reverse("accounts_api:me"),
            {
                "store_name": "North Star Store",
                "is_verified_seller": True,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.user.refresh_from_db()
        self.assertEqual(self.user.store_name, "North Star Store")
        self.assertFalse(self.user.is_verified_seller)

    def test_customer_cannot_set_a_store_name(self):
        self.client.force_authenticate(user=self.user)

        response = self.client.patch(
            reverse("accounts_api:me"),
            {"store_name": "Not A Seller"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("store_name", response.data)


class DeliveryAddressApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="address_customer",
            email="address-customer@example.com",
            password="StrongPass!2026",
        )
        self.other_user = User.objects.create_user(
            username="other_address_customer",
            email="other-address-customer@example.com",
            password="StrongPass!2026",
        )
        self.list_url = reverse("accounts_api:addresses")

    def payload(self, **overrides):
        return {
            "label": "Home",
            "recipient_name": "Arda Korkmaz",
            "phone_number": "+90 555 123 45 67",
            "address_line_1": "Example Street 12",
            "address_line_2": "Apartment 4",
            "district": "Kadikoy",
            "city": "Istanbul",
            "postal_code": "34710",
            "country_code": "TR",
            **overrides,
        }

    def detail_url(self, address):
        return reverse(
            "accounts_api:address_detail",
            kwargs={"address_id": address.pk},
        )

    def authenticate(self, user=None):
        self.client.force_authenticate(user=user or self.user)

    def create_address(self, **overrides):
        self.authenticate()
        response = self.client.post(
            self.list_url,
            self.payload(**overrides),
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        return DeliveryAddress.objects.get(pk=response.data["id"])

    def test_all_address_endpoints_require_authentication(self):
        address = DeliveryAddress.objects.create(
            user=self.user,
            is_default=True,
            **self.payload(),
        )
        detail_url = self.detail_url(address)

        requests = (
            self.client.get(self.list_url),
            self.client.post(self.list_url, self.payload(), format="json"),
            self.client.get(detail_url),
            self.client.patch(detail_url, {"label": "Work"}, format="json"),
            self.client.delete(detail_url),
        )

        for response in requests:
            self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_first_address_is_default_and_input_is_normalized(self):
        self.authenticate()

        response = self.client.post(
            self.list_url,
            self.payload(
                label="  Home  ",
                recipient_name="  Arda Korkmaz  ",
                address_line_2="  Apartment 4  ",
                postal_code="  34710  ",
                country_code="tr",
                is_default=False,
                user=self.other_user.pk,
            ),
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        address = DeliveryAddress.objects.get(pk=response.data["id"])
        self.assertEqual(address.user, self.user)
        self.assertEqual(address.label, "Home")
        self.assertEqual(address.recipient_name, "Arda Korkmaz")
        self.assertEqual(address.address_line_2, "Apartment 4")
        self.assertEqual(address.postal_code, "34710")
        self.assertEqual(address.country_code, "TR")
        self.assertTrue(address.is_default)

    def test_list_returns_default_first_and_new_addresses_are_not_default(self):
        first = self.create_address(label="Home")
        second = self.create_address(label="Work")

        response = self.client.get(self.list_url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual([item["id"] for item in response.data], [first.pk, second.pk])
        self.assertTrue(first.is_default)
        self.assertFalse(second.is_default)

    def test_post_and_patch_can_switch_the_default_address(self):
        first = self.create_address(label="Home")
        second = self.create_address(label="Work", is_default=True)
        first.refresh_from_db()

        self.assertFalse(first.is_default)
        self.assertTrue(second.is_default)

        third = self.create_address(label="Family")
        response = self.client.patch(
            self.detail_url(third),
            {"is_default": True},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        second.refresh_from_db()
        third.refresh_from_db()
        self.assertFalse(second.is_default)
        self.assertTrue(third.is_default)
        self.assertEqual(DeliveryAddress.objects.filter(is_default=True).count(), 1)

    def test_current_default_cannot_be_unset_directly(self):
        address = self.create_address()

        response = self.client.patch(
            self.detail_url(address),
            {"is_default": False},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("is_default", response.data)
        address.refresh_from_db()
        self.assertTrue(address.is_default)

    def test_patch_updates_only_the_owned_address(self):
        address = self.create_address()

        response = self.client.patch(
            self.detail_url(address),
            {"label": "  Office  ", "city": "  Ankara  "},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        address.refresh_from_db()
        self.assertEqual(address.label, "Office")
        self.assertEqual(address.city, "Ankara")

    def test_deleting_the_default_promotes_a_remaining_address(self):
        first = self.create_address(label="Home")
        second = self.create_address(label="Work")

        response = self.client.delete(self.detail_url(first))

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        second.refresh_from_db()
        self.assertTrue(second.is_default)

        response = self.client.delete(self.detail_url(second))
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(DeliveryAddress.objects.filter(user=self.user).exists())

    def test_users_cannot_read_change_or_delete_another_users_address(self):
        foreign_address = DeliveryAddress.objects.create(
            user=self.other_user,
            is_default=True,
            **self.payload(label="Private"),
        )
        self.authenticate()
        detail_url = self.detail_url(foreign_address)

        responses = (
            self.client.get(detail_url),
            self.client.patch(detail_url, {"label": "Changed"}, format="json"),
            self.client.delete(detail_url),
        )

        for response in responses:
            self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        foreign_address.refresh_from_db()
        self.assertEqual(foreign_address.label, "Private")
        self.assertEqual(self.client.get(self.list_url).data, [])

    def test_address_fields_are_validated(self):
        self.authenticate()
        invalid_values = (
            ("label", "   "),
            ("recipient_name", "   "),
            ("address_line_1", "   "),
            ("district", "   "),
            ("city", "   "),
            ("phone_number", "+90 CALL HOME"),
            ("phone_number", "123456"),
            ("postal_code", "34710@"),
            ("country_code", "TUR"),
            ("country_code", "1R"),
        )

        for field, value in invalid_values:
            with self.subTest(field=field, value=value):
                response = self.client.post(
                    self.list_url,
                    self.payload(**{field: value}),
                    format="json",
                )
                self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
                self.assertIn(field, response.data)

        self.assertFalse(DeliveryAddress.objects.filter(user=self.user).exists())

    def test_database_rejects_two_default_addresses_for_one_user(self):
        DeliveryAddress.objects.create(
            user=self.user,
            is_default=True,
            **self.payload(label="Home"),
        )

        with self.assertRaises(IntegrityError):
            with transaction.atomic():
                DeliveryAddress.objects.create(
                    user=self.user,
                    is_default=True,
                    **self.payload(label="Work"),
                )
