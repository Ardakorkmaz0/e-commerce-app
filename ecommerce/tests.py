from decimal import Decimal
from urllib.parse import urlsplit

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.core.management import call_command
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from .management.commands.seed_catalog import DEMO_PRODUCTS
from accounts.models import DeliveryAddress, PaymentMethod

from .payments import charge
from .models import (
    Attribute,
    AttributeValue,
    Category,
    Order,
    Payment,
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


class SellerVariantApiTests(TestCase):
    """The seller panel's variant grid: generate, edit, delete, isolate."""

    def setUp(self):
        self.client = APIClient()

        sellers, _ = Group.objects.get_or_create(name="Sellers")
        self.seller = User.objects.create_user(
            username="variant-seller",
            email="variant-seller@example.com",
            password="pw-for-tests-only",
        )
        self.seller.groups.add(sellers)

        self.other = User.objects.create_user(
            username="other-seller",
            email="other-seller@example.com",
            password="pw-for-tests-only",
        )
        self.other.groups.add(sellers)

        self.category = Category.objects.create(name="Shoes")

        self.size = Attribute.objects.create(name="Size", position=1)
        self.size.categories.add(self.category)
        self.colour = Attribute.objects.create(name="Colour", position=2)
        self.colour.categories.add(self.category)

        self.s40 = AttributeValue.objects.create(
            attribute=self.size, name="40", position=1
        )
        self.s41 = AttributeValue.objects.create(
            attribute=self.size, name="41", position=2
        )
        self.red = AttributeValue.objects.create(
            attribute=self.colour, name="Red", swatch_color="#DC2626", position=1
        )
        self.blue = AttributeValue.objects.create(
            attribute=self.colour, name="Blue", swatch_color="#2563EB", position=2
        )

        # An attribute that belongs to a different category entirely.
        other_category = Category.objects.create(name="Laptops")
        ram = Attribute.objects.create(name="RAM", position=3)
        ram.categories.add(other_category)
        self.ram16 = AttributeValue.objects.create(attribute=ram, name="16 GB")

        self.product = Product.objects.create(
            name="Runner",
            description="A shoe.",
            price=Decimal("80.00"),
            stock=0,
            category=self.category,
            seller=self.seller,
        )

    def url(self, suffix=""):
        return f"/api/v1/seller/products/{self.product.slug}/variants/{suffix}"

    def test_generate_builds_every_combination(self):
        self.client.force_authenticate(self.seller)

        response = self.client.post(
            self.url("generate/"),
            {"value_ids": [self.s40.pk, self.s41.pk, self.red.pk, self.blue.pk]},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.json()["created"], 4)
        self.assertEqual(self.product.variants.count(), 4)
        self.assertEqual(
            sorted(v.option_label for v in self.product.variants.all()),
            ["40 / Blue", "40 / Red", "41 / Blue", "41 / Red"],
        )

    def test_generate_again_only_adds_what_is_missing(self):
        self.client.force_authenticate(self.seller)
        self.client.post(
            self.url("generate/"),
            {"value_ids": [self.s40.pk, self.red.pk]},
            format="json",
        )

        # Same call plus one more size: only the new row should appear.
        response = self.client.post(
            self.url("generate/"),
            {"value_ids": [self.s40.pk, self.s41.pk, self.red.pk]},
            format="json",
        )

        self.assertEqual(response.json()["created"], 1)
        self.assertEqual(response.json()["skipped"], 1)
        self.assertEqual(self.product.variants.count(), 2)

    def test_generate_rejects_values_from_another_category(self):
        self.client.force_authenticate(self.seller)

        response = self.client.post(
            self.url("generate/"),
            {"value_ids": [self.s40.pk, self.ram16.pk]},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(self.product.variants.count(), 0)

    def test_creating_one_by_hand_stores_price_stock_and_picture(self):
        self.client.force_authenticate(self.seller)

        response = self.client.post(
            self.url(),
            {
                "option_values": [self.s40.pk, self.red.pk],
                "price": "95.00",
                "stock": 4,
                "description": "Runs small.",
                "image_url": "https://example.com/red-40.png",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        body = response.json()
        self.assertEqual(body["option_label"], "40 / Red")
        self.assertEqual(body["stock"], 4)
        self.assertEqual(body["image_display"], "https://example.com/red-40.png")

    def test_two_values_of_one_attribute_are_rejected(self):
        self.client.force_authenticate(self.seller)

        response = self.client.post(
            self.url(),
            {"option_values": [self.red.pk, self.blue.pk], "stock": 1},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_a_duplicate_combination_is_rejected(self):
        self.client.force_authenticate(self.seller)
        payload = {"option_values": [self.s40.pk, self.red.pk], "stock": 1}
        self.client.post(self.url(), payload, format="json")

        response = self.client.post(self.url(), payload, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("already exists", str(response.json()))

    def test_editing_a_variant_keeps_its_own_combination_valid(self):
        self.client.force_authenticate(self.seller)
        created = self.client.post(
            self.url(),
            {"option_values": [self.s40.pk, self.red.pk], "stock": 1},
            format="json",
        ).json()

        # Re-sending the same options while changing the stock must not
        # trip the duplicate check on the row being edited.
        response = self.client.patch(
            self.url(str(created["id"]) + "/"),
            {"option_values": [self.s40.pk, self.red.pk], "stock": 9},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()["stock"], 9)

    def test_deleting_a_variant_removes_it(self):
        self.client.force_authenticate(self.seller)
        created = self.client.post(
            self.url(),
            {"option_values": [self.s40.pk, self.red.pk], "stock": 1},
            format="json",
        ).json()

        response = self.client.delete(self.url(str(created["id"]) + "/"))

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(self.product.variants.count(), 0)

    def test_another_seller_cannot_see_or_touch_these_variants(self):
        self.client.force_authenticate(self.seller)
        created = self.client.post(
            self.url(),
            {"option_values": [self.s40.pk, self.red.pk], "stock": 1},
            format="json",
        ).json()
        detail = self.url(str(created["id"]) + "/")

        self.client.force_authenticate(self.other)

        self.assertEqual(self.client.get(self.url()).status_code, 404)
        self.assertEqual(
            self.client.patch(detail, {"stock": 99}, format="json").status_code, 404
        )
        self.assertEqual(self.client.delete(detail).status_code, 404)

    def test_a_shopper_without_a_seller_account_is_refused(self):
        shopper = User.objects.create_user(
            username="plain-shopper",
            email="plain-shopper@example.com",
            password="pw-for-tests-only",
        )
        self.client.force_authenticate(shopper)

        self.assertEqual(self.client.get(self.url()).status_code, 403)

    def test_generated_variants_reach_the_public_product(self):
        self.client.force_authenticate(self.seller)
        self.client.post(
            self.url("generate/"),
            {"value_ids": [self.s40.pk, self.red.pk, self.blue.pk]},
            format="json",
        )
        # A variant with no stock is still a real option; give one some.
        variant = self.product.variants.first()
        variant.stock = 2
        variant.save()

        self.client.force_authenticate(None)
        data = self.client.get(f"/api/v1/products/{self.product.slug}/").json()

        self.assertTrue(data["has_variants"])
        self.assertEqual(len(data["variants"]), 2)
        self.assertEqual(
            [group["name"] for group in data["option_groups"]], ["Size", "Colour"]
        )


class SellerOptionApiTests(TestCase):
    """The "+" buttons: a seller typing their own options."""

    def setUp(self):
        self.client = APIClient()

        sellers, _ = Group.objects.get_or_create(name="Sellers")
        self.seller = User.objects.create_user(
            username="option-seller",
            email="option-seller@example.com",
            password="pw-for-tests-only",
        )
        self.seller.groups.add(sellers)

        self.category = Category.objects.create(name="Sneakers")
        self.colour = Attribute.objects.create(name="Sneaker Colour", position=1)
        self.colour.categories.add(self.category)
        self.red = AttributeValue.objects.create(
            attribute=self.colour, name="Red", swatch_color="#DC2626"
        )

        self.product = Product.objects.create(
            name="Trainer",
            description="A shoe.",
            price=Decimal("70.00"),
            stock=0,
            category=self.category,
            seller=self.seller,
        )
        self.url = f"/api/v1/seller/products/{self.product.slug}/options/"

    def test_adds_a_value_to_an_existing_group(self):
        self.client.force_authenticate(self.seller)

        response = self.client.post(
            self.url,
            {
                "attribute_id": self.colour.pk,
                "name": "Forest Green",
                "swatch_color": "#166534",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        body = response.json()
        self.assertTrue(body["created"])
        self.assertEqual(body["value"]["name"], "Forest Green")
        self.assertEqual(body["value"]["swatch_color"], "#166534")
        self.assertEqual(self.colour.values.count(), 2)

    def test_starts_a_new_group_and_attaches_it_to_the_category(self):
        self.client.force_authenticate(self.seller)

        response = self.client.post(
            self.url,
            {"attribute_name": "Width", "name": "Wide"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        width = Attribute.objects.get(name="Width")
        self.assertIn(self.category, width.categories.all())
        self.assertEqual([v.name for v in width.values.all()], ["Wide"])

    def test_an_existing_group_name_is_reused_not_duplicated(self):
        # Attribute names are unique shop-wide, so typing one that exists
        # must attach it here rather than blow up.
        other = Category.objects.create(name="Boots")
        shared = Attribute.objects.create(name="Width", position=9)
        shared.categories.add(other)

        self.client.force_authenticate(self.seller)
        response = self.client.post(
            self.url,
            {"attribute_name": "width", "name": "Narrow"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Attribute.objects.filter(name__iexact="width").count(), 1)
        shared.refresh_from_db()
        self.assertIn(self.category, shared.categories.all())

    def test_a_value_that_already_exists_is_returned_not_duplicated(self):
        self.client.force_authenticate(self.seller)

        response = self.client.post(
            self.url,
            {"attribute_id": self.colour.pk, "name": "red"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.json()["created"])
        self.assertEqual(response.json()["value"]["id"], self.red.pk)
        self.assertEqual(self.colour.values.count(), 1)

    def test_a_bad_colour_is_rejected(self):
        self.client.force_authenticate(self.seller)

        response = self.client.post(
            self.url,
            {"attribute_id": self.colour.pk, "name": "Teal", "swatch_color": "teal"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_a_blank_name_is_rejected(self):
        self.client.force_authenticate(self.seller)

        response = self.client.post(
            self.url,
            {"attribute_id": self.colour.pk, "name": "   "},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_a_group_from_another_category_is_rejected(self):
        elsewhere = Category.objects.create(name="Laptops")
        ram = Attribute.objects.create(name="Trainer RAM", position=5)
        ram.categories.add(elsewhere)

        self.client.force_authenticate(self.seller)
        response = self.client.post(
            self.url,
            {"attribute_id": ram.pk, "name": "32 GB"},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_another_seller_cannot_add_options_through_this_product(self):
        sellers = Group.objects.get(name="Sellers")
        intruder = User.objects.create_user(
            username="option-intruder",
            email="option-intruder@example.com",
            password="pw-for-tests-only",
        )
        intruder.groups.add(sellers)

        self.client.force_authenticate(intruder)
        response = self.client.post(
            self.url,
            {"attribute_id": self.colour.pk, "name": "Gold"},
            format="json",
        )

        self.assertEqual(response.status_code, 404)


class ProductGalleryApiTests(TestCase):
    """Extra photos: the strip a shopper flips through."""

    def setUp(self):
        self.client = APIClient()

        sellers, _ = Group.objects.get_or_create(name="Sellers")
        self.seller = User.objects.create_user(
            username="gallery-seller",
            email="gallery-seller@example.com",
            password="pw-for-tests-only",
        )
        self.seller.groups.add(sellers)

        self.category = Category.objects.create(name="Cameras")
        self.product = Product.objects.create(
            name="Mirrorless",
            description="A camera.",
            price=Decimal("900.00"),
            stock=3,
            category=self.category,
            seller=self.seller,
            image_url="https://example.com/cover.png",
        )

        colour = Attribute.objects.create(name="Body Colour", position=1)
        colour.categories.add(self.category)
        self.black = AttributeValue.objects.create(
            attribute=colour, name="Black", swatch_color="#111827"
        )
        self.variant = ProductVariant.objects.create(product=self.product, stock=2)
        self.variant.option_values.set([self.black])

        self.url = f"/api/v1/seller/products/{self.product.slug}/images/"

    def test_a_seller_adds_photos_and_they_reach_the_product(self):
        self.client.force_authenticate(self.seller)

        for index in range(3):
            response = self.client.post(
                self.url,
                {
                    "image_url": f"https://example.com/angle-{index}.png",
                    "alt": f"Angle {index}",
                },
                format="json",
            )
            self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        self.client.force_authenticate(None)
        data = self.client.get(f"/api/v1/products/{self.product.slug}/").json()

        self.assertEqual(len(data["images"]), 3)
        self.assertEqual(
            [image["alt"] for image in data["images"]],
            ["Angle 0", "Angle 1", "Angle 2"],
        )
        # The cover stays its own field; the gallery is what comes after.
        self.assertEqual(data["image_url"], "https://example.com/cover.png")

    def test_new_photos_land_at_the_end_of_the_strip(self):
        self.client.force_authenticate(self.seller)

        for index in range(3):
            self.client.post(
                self.url,
                {"image_url": f"https://example.com/{index}.png"},
                format="json",
            )

        self.assertEqual(
            list(self.product.gallery.values_list("position", flat=True)), [0, 1, 2]
        )

    def test_a_photo_can_be_pinned_to_one_variant(self):
        self.client.force_authenticate(self.seller)

        response = self.client.post(
            self.url,
            {
                "image_url": "https://example.com/black.png",
                "variant": self.variant.pk,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.json()["variant"], self.variant.pk)

    def test_a_variant_of_another_product_is_rejected(self):
        other = Product.objects.create(
            name="Lens",
            description="Glass.",
            price=Decimal("300.00"),
            stock=1,
            category=self.category,
            seller=self.seller,
        )
        stray = ProductVariant.objects.create(product=other, stock=1)

        self.client.force_authenticate(self.seller)
        response = self.client.post(
            self.url,
            {"image_url": "https://example.com/x.png", "variant": stray.pk},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_a_photo_with_neither_a_file_nor_a_link_is_rejected(self):
        self.client.force_authenticate(self.seller)

        response = self.client.post(self.url, {"alt": "Nothing"}, format="json")

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_reordering_and_deleting(self):
        self.client.force_authenticate(self.seller)
        first = self.client.post(
            self.url, {"image_url": "https://example.com/a.png"}, format="json"
        ).json()
        second = self.client.post(
            self.url, {"image_url": "https://example.com/b.png"}, format="json"
        ).json()

        moved = self.client.patch(
            f"{self.url}{second['id']}/", {"position": 0}, format="json"
        )
        self.assertEqual(moved.status_code, status.HTTP_200_OK)
        self.assertEqual(
            [image.pk for image in self.product.gallery.all()],
            [second["id"], first["id"]],
        )

        removed = self.client.delete(f"{self.url}{first['id']}/")
        self.assertEqual(removed.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(self.product.gallery.count(), 1)

    def test_another_seller_cannot_touch_this_gallery(self):
        sellers = Group.objects.get(name="Sellers")
        intruder = User.objects.create_user(
            username="gallery-intruder",
            email="gallery-intruder@example.com",
            password="pw-for-tests-only",
        )
        intruder.groups.add(sellers)

        self.client.force_authenticate(self.seller)
        mine = self.client.post(
            self.url, {"image_url": "https://example.com/a.png"}, format="json"
        ).json()

        self.client.force_authenticate(intruder)
        self.assertEqual(self.client.get(self.url).status_code, 404)
        self.assertEqual(
            self.client.delete(f"{self.url}{mine['id']}/").status_code, 404
        )

    def test_deleting_a_variant_takes_its_photos_with_it(self):
        self.client.force_authenticate(self.seller)
        self.client.post(
            self.url,
            {"image_url": "https://example.com/black.png", "variant": self.variant.pk},
            format="json",
        )
        self.client.post(
            self.url, {"image_url": "https://example.com/shared.png"}, format="json"
        )

        self.variant.delete()

        # The shared photo has no variant, so it survives.
        self.assertEqual(
            list(self.product.gallery.values_list("image_url", flat=True)),
            ["https://example.com/shared.png"],
        )

    def test_the_gallery_stops_at_six_photos(self):
        self.client.force_authenticate(self.seller)

        for index in range(6):
            response = self.client.post(
                self.url,
                {"image_url": f"https://example.com/{index}.png"},
                format="json",
            )
            self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        seventh = self.client.post(
            self.url, {"image_url": "https://example.com/7.png"}, format="json"
        )

        self.assertEqual(seventh.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("Remove one", str(seventh.json()))
        self.assertEqual(self.product.gallery.count(), 6)

    def test_a_full_gallery_can_still_be_edited(self):
        self.client.force_authenticate(self.seller)
        ids = [
            self.client.post(
                self.url,
                {"image_url": f"https://example.com/{index}.png"},
                format="json",
            ).json()["id"]
            for index in range(6)
        ]

        # The limit is about adding, not about touching what is there.
        response = self.client.patch(
            f"{self.url}{ids[0]}/", {"alt": "Renamed"}, format="json"
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()["alt"], "Renamed")


class CartShippingTests(TestCase):
    """What the checkout screen quotes for delivery."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username="shipping-shopper",
            email="shipping-shopper@example.com",
            password="pw-for-tests-only",
        )
        self.client.force_authenticate(self.user)

        self.category = Category.objects.create(name="Bits")

    def add(self, price, quantity=1):
        product = Product.objects.create(
            name=f"Item {price}",
            description="x",
            price=Decimal(price),
            stock=50,
            category=self.category,
        )
        return self.client.post(
            "/api/v1/cart/items/",
            {"product_id": product.pk, "quantity": quantity},
            format="json",
        ).json()

    def test_an_empty_cart_is_not_charged_for_delivery(self):
        body = self.client.get("/api/v1/cart/").json()

        self.assertEqual(Decimal(body["shipping"]), Decimal("0.00"))
        self.assertEqual(Decimal(body["total"]), Decimal("0.00"))
        # "Spend 50.00 more" beside a delivery cost of 0.00 reads as a
        # contradiction, so an empty cart quotes no gap either.
        self.assertEqual(
            Decimal(body["free_shipping_remaining"]), Decimal("0.00")
        )

    def test_a_small_order_pays_the_flat_fee(self):
        body = self.add("20.00")

        self.assertEqual(Decimal(body["subtotal"]), Decimal("20.00"))
        self.assertEqual(Decimal(body["shipping"]), Decimal("9.90"))
        self.assertEqual(Decimal(body["total"]), Decimal("29.90"))
        self.assertEqual(
            Decimal(body["free_shipping_remaining"]), Decimal("30.00")
        )

    def test_reaching_the_threshold_exactly_ships_free(self):
        body = self.add("25.00", quantity=2)

        self.assertEqual(Decimal(body["subtotal"]), Decimal("50.00"))
        self.assertEqual(Decimal(body["shipping"]), Decimal("0.00"))
        self.assertEqual(Decimal(body["total"]), Decimal("50.00"))
        self.assertEqual(
            Decimal(body["free_shipping_remaining"]), Decimal("0.00")
        )

    def test_going_over_the_threshold_still_ships_free(self):
        body = self.add("120.00")

        self.assertEqual(Decimal(body["shipping"]), Decimal("0.00"))
        self.assertEqual(Decimal(body["total"]), Decimal("120.00"))

    def test_the_threshold_travels_with_the_cart(self):
        body = self.add("10.00")

        # The client shows "spend X more" without knowing the rule.
        self.assertEqual(body["free_shipping_threshold"], "50.00")


class OrderApiTests(TestCase):
    """Placing, paying for, shipping and cancelling an order."""

    def setUp(self):
        self.client = APIClient()
        sellers, _ = Group.objects.get_or_create(name="Sellers")

        self.seller_a = User.objects.create_user(
            username="order-seller-a",
            email="order-seller-a@example.com",
            password="pw-for-tests-only",
            store_name="Store A",
        )
        self.seller_b = User.objects.create_user(
            username="order-seller-b",
            email="order-seller-b@example.com",
            password="pw-for-tests-only",
            store_name="Store B",
        )
        self.seller_a.groups.add(sellers)
        self.seller_b.groups.add(sellers)

        self.shopper = User.objects.create_user(
            username="order-shopper",
            email="order-shopper@example.com",
            password="pw-for-tests-only",
        )

        self.category = Category.objects.create(name="Order Things")
        self.from_a = Product.objects.create(
            name="Thing from A",
            description="x",
            price=Decimal("30.00"),
            stock=5,
            category=self.category,
            seller=self.seller_a,
        )
        self.from_b = Product.objects.create(
            name="Thing from B",
            description="x",
            price=Decimal("25.00"),
            stock=2,
            category=self.category,
            seller=self.seller_b,
        )

        self.address = DeliveryAddress.objects.create(
            user=self.shopper,
            label="Home",
            recipient_name="Test Shopper",
            phone_number="+90 555 000 00 00",
            address_line_1="Sokak 1",
            district="Kadikoy",
            city="Istanbul",
            postal_code="34710",
            is_default=True,
        )
        self.good_card = PaymentMethod.objects.create(
            user=self.shopper,
            brand="visa",
            last4="4242",
            exp_month=12,
            exp_year=2038,
            holder_name="TEST SHOPPER",
            provider_token="tok_good",
            is_default=True,
        )
        self.declined_card = PaymentMethod.objects.create(
            user=self.shopper,
            brand="visa",
            last4="0002",
            exp_month=12,
            exp_year=2038,
            holder_name="TEST SHOPPER",
            provider_token="tok_declined",
        )

    # ── helpers ──────────────────────────────────────────────────────

    def fill_cart(self):
        self.client.force_authenticate(self.shopper)
        self.client.post(
            "/api/v1/cart/items/",
            {"product_id": self.from_a.pk, "quantity": 1},
            format="json",
        )
        self.client.post(
            "/api/v1/cart/items/",
            {"product_id": self.from_b.pk, "quantity": 1},
            format="json",
        )

    def place(self, card=None, **extra):
        return self.client.post(
            "/api/v1/orders/",
            {
                "address_id": self.address.pk,
                "payment_method_id": (card or self.good_card).pk,
                **extra,
            },
            format="json",
        )

    # ── placing ──────────────────────────────────────────────────────

    def test_a_paid_order_copies_the_cart_and_takes_the_stock(self):
        self.fill_cart()

        response = self.place()

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        body = response.json()
        self.assertEqual(body["status"], "paid")
        self.assertEqual(Decimal(body["total"]), Decimal("55.00"))
        self.assertRegex(body["order_number"], r"^VD-\d{4}-\d{5}$")

        self.from_a.refresh_from_db()
        self.from_b.refresh_from_db()
        self.assertEqual((self.from_a.stock, self.from_b.stock), (4, 1))

        # The cart is spent.
        self.assertEqual(self.client.get("/api/v1/cart/").json()["item_count"], 0)

    def test_the_lines_are_copies_that_survive_the_product(self):
        self.fill_cart()
        self.place()

        self.from_a.delete()

        body = self.client.get("/api/v1/orders/").json()[0]
        names = sorted(item["name"] for item in body["items"])
        self.assertEqual(names, ["Thing from A", "Thing from B"])
        line = next(i for i in body["items"] if i["name"] == "Thing from A")
        self.assertEqual(Decimal(line["unit_price"]), Decimal("30.00"))
        self.assertEqual(line["seller_name"], "Store A")

    def test_a_price_change_does_not_reach_a_placed_order(self):
        self.fill_cart()
        self.place()

        self.from_a.price = Decimal("999.00")
        self.from_a.save(update_fields=["price"])

        body = self.client.get("/api/v1/orders/").json()[0]
        self.assertEqual(Decimal(body["total"]), Decimal("55.00"))

    def test_the_address_is_copied_not_linked(self):
        self.fill_cart()
        self.place()
        self.address.delete()

        body = self.client.get("/api/v1/orders/").json()[0]
        self.assertEqual(body["recipient_name"], "Test Shopper")
        self.assertEqual(body["city"], "Istanbul")

    def test_an_empty_cart_cannot_be_ordered(self):
        self.client.force_authenticate(self.shopper)

        response = self.place()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("empty", str(response.json()).lower())

    # ── payment ──────────────────────────────────────────────────────

    def test_a_declined_card_leaves_the_shop_untouched(self):
        self.fill_cart()

        response = self.place(card=self.declined_card)

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("declined", str(response.json()).lower())

        self.from_a.refresh_from_db()
        self.from_b.refresh_from_db()
        self.assertEqual((self.from_a.stock, self.from_b.stock), (5, 2))
        self.assertEqual(self.client.get("/api/v1/cart/").json()["item_count"], 2)

    def test_a_declined_order_is_kept_with_its_reason(self):
        self.fill_cart()
        self.place(card=self.declined_card)

        # It has to survive the failure, or there is nothing to retry.
        order = Order.objects.get(user=self.shopper)
        self.assertEqual(order.status, Order.Status.PENDING)
        self.assertEqual(order.payments.count(), 1)
        self.assertEqual(order.payments.first().status, Payment.Status.FAILED)

        body = self.client.get(f"/api/v1/orders/{order.order_number}/").json()
        self.assertEqual(body["last_payment_error"], "Your card was declined.")

    def test_retrying_with_a_good_card_works(self):
        self.fill_cart()
        self.place(card=self.declined_card)

        response = self.place()

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.json()["status"], "paid")

    def test_an_expired_card_is_refused_before_charging(self):
        self.fill_cart()
        expired = PaymentMethod.objects.create(
            user=self.shopper,
            brand="visa",
            last4="4242",
            exp_month=1,
            exp_year=2020,
            holder_name="TEST SHOPPER",
            provider_token="tok_expired",
        )

        response = self.place(card=expired)

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(Payment.objects.count(), 0)

    def test_another_shoppers_card_cannot_be_used(self):
        self.fill_cart()
        stranger_card = PaymentMethod.objects.create(
            user=self.seller_a,
            brand="visa",
            last4="4242",
            exp_month=12,
            exp_year=2038,
            holder_name="SOMEONE ELSE",
            provider_token="tok_stranger",
        )

        response = self.place(card=stranger_card)

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    # ── idempotency ──────────────────────────────────────────────────

    def test_a_repeated_key_returns_the_same_order(self):
        self.fill_cart()
        first = self.place(idempotency_key="abc-123")
        self.assertEqual(first.status_code, status.HTTP_201_CREATED)

        second = self.place(idempotency_key="abc-123")

        # Nothing was created, so it is not a 201.
        self.assertEqual(second.status_code, status.HTTP_200_OK)
        self.assertEqual(
            second.json()["order_number"], first.json()["order_number"]
        )
        self.assertEqual(Order.objects.filter(user=self.shopper).count(), 1)

    def test_two_shoppers_may_send_the_same_key(self):
        other = User.objects.create_user(
            username="order-shopper-2",
            email="order-shopper-2@example.com",
            password="pw-for-tests-only",
        )
        DeliveryAddress.objects.create(
            user=other,
            label="Home",
            recipient_name="Other",
            phone_number="+90 555 111 11 11",
            address_line_1="Sokak 2",
            district="Besiktas",
            city="Istanbul",
        )
        PaymentMethod.objects.create(
            user=other,
            brand="visa",
            last4="4242",
            exp_month=12,
            exp_year=2038,
            holder_name="OTHER",
            provider_token="tok_other",
        )

        self.fill_cart()
        self.place(idempotency_key="shared")

        self.client.force_authenticate(other)
        self.client.post(
            "/api/v1/cart/items/",
            {"product_id": self.from_a.pk, "quantity": 1},
            format="json",
        )
        response = self.client.post(
            "/api/v1/orders/",
            {
                "address_id": other.delivery_addresses.first().pk,
                "payment_method_id": other.payment_methods.first().pk,
                "idempotency_key": "shared",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    # ── stock ────────────────────────────────────────────────────────

    def test_an_order_is_refused_whole_when_one_line_ran_out(self):
        self.fill_cart()
        self.from_b.stock = 0
        self.from_b.save(update_fields=["stock"])

        response = self.place()

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("only 0 left", str(response.json()))
        # The line that was available is not taken either.
        self.from_a.refresh_from_db()
        self.assertEqual(self.from_a.stock, 5)

    # ── shipping and delivery ────────────────────────────────────────

    def test_the_order_ships_only_once_every_seller_has_posted(self):
        self.fill_cart()
        number = self.place().json()["order_number"]

        self.client.force_authenticate(self.seller_a)
        self.client.post(f"/api/v1/seller/orders/{number}/ship/")

        self.client.force_authenticate(self.shopper)
        self.assertEqual(
            self.client.get(f"/api/v1/orders/{number}/").json()["status"], "paid"
        )

        self.client.force_authenticate(self.seller_b)
        self.client.post(f"/api/v1/seller/orders/{number}/ship/")

        self.client.force_authenticate(self.shopper)
        self.assertEqual(
            self.client.get(f"/api/v1/orders/{number}/").json()["status"],
            "shipped",
        )

    def test_a_seller_cannot_ship_twice(self):
        self.fill_cart()
        number = self.place().json()["order_number"]

        self.client.force_authenticate(self.seller_a)
        self.client.post(f"/api/v1/seller/orders/{number}/ship/")
        again = self.client.post(f"/api/v1/seller/orders/{number}/ship/")

        self.assertEqual(again.status_code, status.HTTP_400_BAD_REQUEST)

    def test_delivery_can_only_be_confirmed_after_shipping(self):
        self.fill_cart()
        number = self.place().json()["order_number"]

        too_early = self.client.post(f"/api/v1/orders/{number}/delivered/")
        self.assertEqual(too_early.status_code, status.HTTP_400_BAD_REQUEST)

        for seller in (self.seller_a, self.seller_b):
            self.client.force_authenticate(seller)
            self.client.post(f"/api/v1/seller/orders/{number}/ship/")

        self.client.force_authenticate(self.shopper)
        done = self.client.post(f"/api/v1/orders/{number}/delivered/")

        self.assertEqual(done.status_code, status.HTTP_200_OK)
        self.assertEqual(done.json()["status"], "delivered")

    # ── cancelling ───────────────────────────────────────────────────

    def test_cancelling_puts_the_stock_back(self):
        self.fill_cart()
        number = self.place().json()["order_number"]

        response = self.client.post(f"/api/v1/orders/{number}/cancel/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.json()["status"], "cancelled")
        self.from_a.refresh_from_db()
        self.from_b.refresh_from_db()
        self.assertEqual((self.from_a.stock, self.from_b.stock), (5, 2))

    def test_one_seller_shipping_closes_cancelling_for_the_whole_order(self):
        self.fill_cart()
        number = self.place().json()["order_number"]

        self.client.force_authenticate(self.seller_a)
        self.client.post(f"/api/v1/seller/orders/{number}/ship/")

        self.client.force_authenticate(self.shopper)
        detail = self.client.get(f"/api/v1/orders/{number}/").json()
        self.assertFalse(detail["is_cancellable"])

        response = self.client.post(f"/api/v1/orders/{number}/cancel/")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("already been shipped", str(response.json()))

    def test_cancelling_twice_is_refused(self):
        self.fill_cart()
        number = self.place().json()["order_number"]
        self.client.post(f"/api/v1/orders/{number}/cancel/")

        again = self.client.post(f"/api/v1/orders/{number}/cancel/")

        self.assertEqual(again.status_code, status.HTTP_400_BAD_REQUEST)

    # ── who sees what ────────────────────────────────────────────────

    def test_a_seller_sees_only_their_own_lines(self):
        self.fill_cart()
        self.place()

        self.client.force_authenticate(self.seller_a)
        rows = self.client.get("/api/v1/seller/orders/").json()

        self.assertEqual(len(rows), 1)
        self.assertEqual([i["name"] for i in rows[0]["items"]], ["Thing from A"])
        self.assertEqual(Decimal(rows[0]["seller_total"]), Decimal("30.00"))

    def test_a_seller_gets_the_address_but_not_the_customer_account(self):
        self.fill_cart()
        self.place()

        self.client.force_authenticate(self.seller_a)
        row = self.client.get("/api/v1/seller/orders/").json()[0]

        # Enough to post a parcel...
        self.assertEqual(row["recipient_name"], "Test Shopper")
        self.assertEqual(row["city"], "Istanbul")
        # ...and nothing about the account behind it.
        self.assertNotIn("order-shopper@example.com", str(row))
        self.assertNotIn("user", row)

    def test_a_seller_cannot_open_the_customer_view_of_the_order(self):
        self.fill_cart()
        number = self.place().json()["order_number"]

        self.client.force_authenticate(self.seller_a)
        response = self.client.get(f"/api/v1/orders/{number}/")

        self.assertEqual(response.status_code, 404)

    def test_a_seller_with_no_line_on_an_order_cannot_ship_it(self):
        self.client.force_authenticate(self.shopper)
        self.client.post(
            "/api/v1/cart/items/",
            {"product_id": self.from_a.pk, "quantity": 1},
            format="json",
        )
        number = self.place().json()["order_number"]

        self.client.force_authenticate(self.seller_b)
        response = self.client.post(f"/api/v1/seller/orders/{number}/ship/")

        self.assertEqual(response.status_code, 404)

    def test_orders_are_private_to_their_owner(self):
        self.fill_cart()
        number = self.place().json()["order_number"]

        stranger = User.objects.create_user(
            username="order-stranger",
            email="order-stranger@example.com",
            password="pw-for-tests-only",
        )
        self.client.force_authenticate(stranger)

        self.assertEqual(
            self.client.get(f"/api/v1/orders/{number}/").status_code, 404
        )
        self.assertEqual(self.client.get("/api/v1/orders/").json(), [])

    def test_signing_out_hides_orders(self):
        self.fill_cart()
        self.place()
        self.client.force_authenticate(None)

        self.assertEqual(self.client.get("/api/v1/orders/").status_code, 401)


class FakePaymentProviderTests(TestCase):
    """The stand-in provider, so its behaviour is pinned down."""

    def test_an_ordinary_card_succeeds(self):
        result = charge(amount=Decimal("10.00"), brand="visa", last4="4242")

        self.assertTrue(result.succeeded)
        self.assertTrue(result.reference.startswith("pay_"))
        self.assertEqual(result.failure_reason, "")

    def test_the_published_test_cards_fail_the_same_way_every_time(self):
        for last4, expected in (
            ("0002", "declined"),
            ("9995", "insufficient funds"),
            ("9987", "lost or stolen"),
        ):
            with self.subTest(last4=last4):
                first = charge(amount=Decimal("10.00"), brand="visa", last4=last4)
                second = charge(amount=Decimal("10.00"), brand="visa", last4=last4)

                self.assertFalse(first.succeeded)
                self.assertFalse(second.succeeded)
                self.assertIn(expected, first.failure_reason.lower())

    def test_nothing_to_charge_is_a_failure(self):
        result = charge(amount=Decimal("0.00"), brand="visa", last4="4242")

        self.assertFalse(result.succeeded)
