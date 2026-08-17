from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken


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
