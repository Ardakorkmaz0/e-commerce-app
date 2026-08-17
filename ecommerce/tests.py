from decimal import Decimal
from urllib.parse import urlsplit

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.core.management import call_command
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from .management.commands.seed_catalog import DEMO_PRODUCTS
from .models import (
    Attribute,
    AttributeValue,
    Category,
    Product,
    ProductVariant,
    SellerRating,
)


User = get_user_model()


class SeedCatalogCommandTests(TestCase):
    def test_command_creates_the_demo_catalog(self):
        call_command("seed_catalog", verbosity=0)

        self.assertEqual(Product.objects.count(), len(DEMO_PRODUCTS))
        self.assertTrue(Product.objects.filter(image_url__startswith="https://").exists())

    def test_command_is_repeatable(self):
        call_command("seed_catalog", verbosity=0)
        call_command("seed_catalog", verbosity=0)

        self.assertEqual(Product.objects.count(), len(DEMO_PRODUCTS))

    def test_command_assigns_filterable_product_specs(self):
        call_command("seed_catalog", verbosity=0)

        laptop = Product.objects.get(slug="vader-apex-14-laptop")
        self.assertTrue(Attribute.objects.filter(slug="product-type").exists())
        self.assertGreaterEqual(laptop.attribute_values.count(), 5)


class ProductCatalogApiTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command("seed_catalog", verbosity=0)

    def setUp(self):
        self.client = APIClient()

    def test_products_are_paginated_in_stable_batches(self):
        url = "/api/v1/products/"
        product_ids = []
        page_count = 0

        while url:
            response = self.client.get(url)
            self.assertEqual(response.status_code, status.HTTP_200_OK)
            payload = response.json()
            page_count += 1

            self.assertEqual(payload["count"], len(DEMO_PRODUCTS))
            self.assertLessEqual(len(payload["results"]), 12)
            product_ids.extend(item["id"] for item in payload["results"])

            next_url = payload["next"]
            if next_url:
                parsed = urlsplit(next_url)
                url = f"{parsed.path}?{parsed.query}"
            else:
                url = None

        self.assertGreater(page_count, 1)
        self.assertEqual(len(product_ids), len(DEMO_PRODUCTS))
        self.assertEqual(len(set(product_ids)), len(DEMO_PRODUCTS))

    def test_price_availability_and_attribute_filters_run_before_pagination(self):
        cheap = self.client.get("/api/v1/products/?price_range=under-50").json()
        low_stock = self.client.get(
            "/api/v1/products/?availability=low_stock"
        ).json()
        laptop = self.client.get(
            "/api/v1/products/?category=computers&product-type=laptop&q=Apex+14"
        ).json()

        self.assertGreater(cheap["count"], 0)
        self.assertTrue(
            all(Decimal(item["price"]) < Decimal("50") for item in cheap["results"])
        )
        self.assertGreater(low_stock["count"], 0)
        self.assertTrue(
            all(1 <= item["stock"] <= 10 for item in low_stock["results"])
        )
        self.assertEqual(laptop["count"], 1)
        self.assertEqual(laptop["results"][0]["slug"], "vader-apex-14-laptop")

    def test_facets_include_global_and_category_specific_filters(self):
        global_facets = self.client.get("/api/v1/facets/").json()
        computer_facets = self.client.get(
            "/api/v1/facets/?category=computers"
        ).json()

        self.assertGreaterEqual(len(global_facets["categories"]), 6)
        self.assertEqual(len(global_facets["price"]["ranges"]), 5)
        self.assertIn("low_stock", global_facets["availability"])
        self.assertIn(
            "product-type",
            {item["slug"] for item in computer_facets["attributes"]},
        )

    def test_page_size_is_capped(self):
        category = Product.objects.first().category
        template = Product.objects.first()
        for index in range(30):
            Product.objects.create(
                name=f"Pagination product {index}",
                slug=f"pagination-product-{index}",
                description="Pagination test product.",
                price=template.price,
                stock=1,
                category=category,
            )

        payload = self.client.get("/api/v1/products/?page_size=100").json()
        self.assertEqual(len(payload["results"]), 24)


class SellerRatingApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        seller_group = Group.objects.create(name="Sellers")
        self.seller = User.objects.create_user(
            username="seller",
            email="seller@example.com",
            password="StrongPass!2026",
            store_name="Verified Store",
            is_verified_seller=True,
        )
        self.seller.groups.add(seller_group)
        self.customer = User.objects.create_user(
            username="customer",
            email="customer@example.com",
            password="StrongPass!2026",
        )
        self.other_customer = User.objects.create_user(
            username="other_customer",
            email="other@example.com",
            password="StrongPass!2026",
        )
        self.url = f"/api/v1/sellers/{self.seller.pk}/rating/"

    def authenticate(self, user=None):
        self.client.force_authenticate(user=user or self.customer)

    def test_rating_endpoint_requires_authentication(self):
        for method, payload in (
            (self.client.get, None),
            (self.client.put, {"score": 5}),
            (self.client.delete, None),
        ):
            response = method(self.url, payload, format="json") if payload else method(
                self.url
            )
            self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_get_returns_no_current_score_for_an_unrated_seller(self):
        self.authenticate()

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.json(),
            {
                "seller_id": self.seller.pk,
                "score": None,
                "rating": None,
                "rating_count": 0,
            },
        )

    def test_put_creates_then_updates_one_rating(self):
        self.authenticate()

        created = self.client.put(self.url, {"score": 2}, format="json")
        updated = self.client.put(self.url, {"score": 5}, format="json")

        self.assertEqual(created.status_code, status.HTTP_200_OK)
        self.assertEqual(updated.status_code, status.HTTP_200_OK)
        self.assertEqual(SellerRating.objects.count(), 1)
        rating = SellerRating.objects.get()
        self.assertEqual(rating.customer, self.customer)
        self.assertEqual(rating.seller, self.seller)
        self.assertEqual(rating.score, 5)
        self.assertEqual(updated.json()["score"], 5)
        self.assertEqual(updated.json()["rating"], 5.0)
        self.assertEqual(updated.json()["rating_count"], 1)

    def test_put_rejects_scores_outside_one_to_five(self):
        self.authenticate()

        for score in (0, 6):
            response = self.client.put(self.url, {"score": score}, format="json")
            self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

        self.assertFalse(SellerRating.objects.exists())

    def test_seller_cannot_rate_themselves(self):
        self.authenticate(self.seller)

        response = self.client.put(self.url, {"score": 5}, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(SellerRating.objects.exists())

    def test_target_must_be_an_active_seller(self):
        regular_user = User.objects.create_user(
            username="regular_target",
            email="regular@example.com",
            password="StrongPass!2026",
        )
        inactive_seller = User.objects.create_user(
            username="inactive_seller",
            email="inactive@example.com",
            password="StrongPass!2026",
            is_active=False,
        )
        inactive_seller.groups.add(Group.objects.get(name="Sellers"))
        self.authenticate()

        for seller in (regular_user, inactive_seller):
            response = self.client.put(
                f"/api/v1/sellers/{seller.pk}/rating/",
                {"score": 4},
                format="json",
            )
            self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_get_returns_the_current_score_and_all_customer_statistics(self):
        SellerRating.objects.create(
            seller=self.seller,
            customer=self.customer,
            score=2,
        )
        SellerRating.objects.create(
            seller=self.seller,
            customer=self.other_customer,
            score=5,
        )
        self.authenticate()

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()["score"], 2)
        self.assertEqual(response.json()["rating"], 3.5)
        self.assertEqual(response.json()["rating_count"], 2)

    def test_delete_is_idempotent(self):
        SellerRating.objects.create(
            seller=self.seller,
            customer=self.customer,
            score=4,
        )
        self.authenticate()

        first = self.client.delete(self.url)
        second = self.client.delete(self.url)

        self.assertEqual(first.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(second.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(SellerRating.objects.exists())


class ProductSellerPayloadTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        seller_group = Group.objects.create(name="Sellers")
        self.seller = User.objects.create_user(
            username="catalog_seller",
            email="catalog-seller@example.com",
            password="StrongPass!2026",
            store_name="Catalog Store",
            is_verified_seller=True,
        )
        self.seller.groups.add(seller_group)
        self.customer = User.objects.create_user(
            username="catalog_customer",
            email="catalog-customer@example.com",
            password="StrongPass!2026",
        )
        self.other_customer = User.objects.create_user(
            username="catalog_customer_two",
            email="catalog-customer-two@example.com",
            password="StrongPass!2026",
        )
        self.category = Category.objects.create(name="Test Category")

    def test_public_product_contains_seller_identity_and_rating(self):
        product = Product.objects.create(
            name="Seller Product",
            description="A product with a visible seller.",
            price=Decimal("25.00"),
            stock=5,
            category=self.category,
            seller=self.seller,
        )
        SellerRating.objects.create(
            seller=self.seller,
            customer=self.customer,
            score=4,
        )
        SellerRating.objects.create(
            seller=self.seller,
            customer=self.other_customer,
            score=5,
        )

        response = self.client.get(f"/api/v1/products/{product.slug}/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            response.json()["seller"],
            {
                "id": self.seller.pk,
                "name": "Catalog Store",
                "is_verified": True,
                "rating": 4.5,
                "rating_count": 2,
            },
        )

    def test_public_product_keeps_legacy_null_seller_compatible(self):
        product = Product.objects.create(
            name="Legacy Product",
            description="A product created before sellers were assigned.",
            price=Decimal("15.00"),
            stock=2,
            category=self.category,
            seller=None,
        )

        response = self.client.get(f"/api/v1/products/{product.slug}/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIsNone(response.json()["seller"])


class ProductVariantApiTests(TestCase):
    """The rules the pickers on web and mobile are built on."""

    def setUp(self):
        self.client = APIClient()
        self.category = Category.objects.create(name="Consoles")

        self.user = User.objects.create_user(
            username="shopper",
            email="shopper@example.com",
            password="pw-for-tests-only",
        )

        self.product = Product.objects.create(
            name="PlayStation 5",
            description="Base description.",
            price=Decimal("649.00"),
            stock=0,
            category=self.category,
        )

        colour = Attribute.objects.create(name="Colour", position=1)
        storage = Attribute.objects.create(name="Storage", position=2)

        self.white = AttributeValue.objects.create(
            attribute=colour, name="White", swatch_color="#F8FAFC", position=1
        )
        self.black = AttributeValue.objects.create(
            attribute=colour, name="Black", swatch_color="#111827", position=2
        )
        self.one_tb = AttributeValue.objects.create(
            attribute=storage, name="1 TB", position=1
        )
        self.two_tb = AttributeValue.objects.create(
            attribute=storage, name="2 TB", position=2
        )

        # Deliberately not every combination: White/2 TB was never built.
        self.white_1tb = ProductVariant.objects.create(
            product=self.product, price=Decimal("649.00"), stock=0
        )
        self.white_1tb.option_values.set([self.white, self.one_tb])

        self.black_2tb = ProductVariant.objects.create(
            product=self.product,
            price=Decimal("899.00"),
            stock=3,
            description="The roomy one.",
        )
        self.black_2tb.option_values.set([self.black, self.two_tb])

    def test_detail_lists_groups_and_variants(self):
        response = self.client.get(f"/api/v1/products/{self.product.slug}/")
        data = response.json()

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertTrue(data["has_variants"])
        self.assertEqual(
            [group["name"] for group in data["option_groups"]],
            ["Colour", "Storage"],
        )
        self.assertEqual(
            data["option_groups"][0]["values"][0]["swatch_color"], "#F8FAFC"
        )

        # Sorted, so a client can compare its selection position by position.
        for variant in data["variants"]:
            self.assertEqual(
                variant["option_value_ids"], sorted(variant["option_value_ids"])
            )

    def test_variant_label_orders_by_attribute(self):
        self.assertEqual(self.black_2tb.option_label, "Black / 2 TB")

    def test_variant_falls_back_to_the_product_price(self):
        plain = ProductVariant.objects.create(product=self.product, stock=1)
        self.assertEqual(plain.effective_price, self.product.price)

    def test_adding_without_a_variant_is_rejected(self):
        self.client.force_authenticate(self.user)

        response = self.client.post(
            "/api/v1/cart/items/",
            {"product_id": self.product.pk, "quantity": 1},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_adding_a_sold_out_variant_is_rejected(self):
        self.client.force_authenticate(self.user)

        response = self.client.post(
            "/api/v1/cart/items/",
            {
                "product_id": self.product.pk,
                "variant_id": self.white_1tb.pk,
                "quantity": 1,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_adding_a_variant_prices_and_labels_the_line(self):
        self.client.force_authenticate(self.user)

        response = self.client.post(
            "/api/v1/cart/items/",
            {
                "product_id": self.product.pk,
                "variant_id": self.black_2tb.pk,
                "quantity": 2,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        line = response.json()["items"][0]
        self.assertEqual(line["variant_id"], self.black_2tb.pk)
        self.assertEqual(line["option_label"], "Black / 2 TB")
        self.assertEqual(Decimal(line["unit_price"]), Decimal("899.00"))
        self.assertEqual(Decimal(line["line_total"]), Decimal("1798.00"))

    def test_a_variant_id_on_a_plain_product_is_rejected(self):
        plain = Product.objects.create(
            name="Controller",
            description="No options.",
            price=Decimal("59.00"),
            stock=5,
            category=self.category,
        )
        self.client.force_authenticate(self.user)

        response = self.client.post(
            "/api/v1/cart/items/",
            {
                "product_id": plain.pk,
                "variant_id": self.black_2tb.pk,
                "quantity": 1,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
