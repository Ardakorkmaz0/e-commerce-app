from decimal import Decimal
from uuid import uuid4

from django.conf import settings
from django.db import models
from django.db.models import Q
from django.utils.text import slugify


class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(max_length=120, unique=True, blank=True)

    class Meta:
        verbose_name_plural = "categories"
        ordering = ("name",)

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)


class Attribute(models.Model):
    """
    A filterable property, such as Brand, Series or RAM.

    Attributes are attached to categories, so the filter panel shown for
    graphics cards (Brand, Series) differs from the one shown for shoes
    (Size, Colour) without either needing its own database column.
    """

    name = models.CharField(max_length=80, unique=True)
    slug = models.SlugField(max_length=90, unique=True, blank=True)
    categories = models.ManyToManyField(
        Category,
        related_name="attributes",
        blank=True,
        help_text="Categories whose filter panel shows this attribute.",
    )
    position = models.PositiveIntegerField(
        default=0,
        help_text="Lower numbers appear first in the filter panel.",
    )

    class Meta:
        ordering = ("position", "name")

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)


class AttributeValue(models.Model):
    """
    One choice of an attribute: RTX and AMD are values of Brand.

    The same values do double duty. They filter the catalog, and they are
    what a variant is made of — a shoe's "US 7" is both something to filter
    by and something to buy.
    """

    attribute = models.ForeignKey(
        Attribute,
        on_delete=models.CASCADE,
        related_name="values",
    )
    name = models.CharField(max_length=80)
    slug = models.SlugField(max_length=90, blank=True)
    position = models.PositiveIntegerField(default=0)

    # Lets a colour render as a dot instead of a word. Empty for anything
    # that is not a colour, such as a size.
    swatch_color = models.CharField(
        max_length=7,
        blank=True,
        help_text="Hex colour like #1D4ED8, for values shown as a swatch.",
    )

    class Meta:
        ordering = ("position", "name")
        # Slugs only need to be unique inside their own attribute, so
        # Brand and Series can both have a value called "Pro".
        constraints = [
            models.UniqueConstraint(
                fields=("attribute", "slug"),
                name="unique_value_slug_per_attribute",
            )
        ]

    def __str__(self):
        return f"{self.attribute.name}: {self.name}"

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)


class Product(models.Model):
    name = models.CharField(max_length=200)
    slug = models.SlugField(max_length=220, unique=True, blank=True)
    description = models.TextField(blank=True)

    # Money is stored as Decimal, never float, so prices stay exact.
    price = models.DecimalField(max_digits=10, decimal_places=2)

    stock = models.PositiveIntegerField(default=0)

    # PROTECT: deleting a category must not silently delete its products.
    category = models.ForeignKey(
        Category,
        on_delete=models.PROTECT,
        related_name="products",
    )

    # Who owns this listing. SET_NULL rather than CASCADE: removing a seller
    # account must not erase products that past orders may refer to.
    # Null means "no owner", which only superusers can see and manage.
    seller = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="products",
    )

    # Two ways to give a product a picture: upload a file, or paste a link.
    # The uploaded file wins when both are set (see ProductSerializer).
    image = models.ImageField(upload_to="products/%Y/%m/", blank=True)
    image_url = models.URLField(blank=True)

    # What the product "is" for filtering: RTX, 3060, 8GB, and so on.
    attribute_values = models.ManyToManyField(
        AttributeValue,
        related_name="products",
        blank=True,
    )

    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-created_at",)

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)

    @property
    def in_stock(self):
        """Stock lives on the variants once a product has any."""
        if self.has_variants:
            return any(variant.in_stock for variant in self.active_variants)
        return self.stock > 0

    @property
    def display_image(self):
        """The uploaded file if there is one, otherwise the pasted link."""
        if self.image:
            return self.image.url
        return self.image_url

    @property
    def active_variants(self):
        return [variant for variant in self.variants.all() if variant.is_active]

    @property
    def has_variants(self):
        return bool(self.active_variants)

    @property
    def total_stock(self):
        if self.has_variants:
            return sum(variant.stock for variant in self.active_variants)
        return self.stock

    @property
    def price_range(self):
        """(low, high) across variants; equal values for a plain product."""
        if not self.has_variants:
            return (self.price, self.price)
        prices = [variant.effective_price for variant in self.active_variants]
        return (min(prices), max(prices))


class ProductVariant(models.Model):
    """
    One buyable combination of a product: "White, 1 controller, 1 TB".

    A product without variants is sold as itself and its own price and
    stock apply. As soon as it has variants, the variant is what goes in
    the cart, and the variant's price, stock and picture take over.

    Price and description are nullable overrides rather than copies: most
    variants differ only in stock and picture, and leaving them empty means
    "same as the product", so a price change does not have to be repeated
    across every row.
    """

    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name="variants",
    )

    # The combination itself: one value per attribute, e.g. Colour: White
    # plus Storage: 1 TB.
    option_values = models.ManyToManyField(
        AttributeValue,
        related_name="variants",
        blank=True,
    )

    sku = models.CharField(max_length=64, unique=True, blank=True)

    price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Leave empty to use the product's price.",
    )
    stock = models.PositiveIntegerField(default=0)

    description = models.TextField(
        blank=True,
        help_text="Shown instead of the product description when set.",
    )

    image = models.ImageField(upload_to="variants/%Y/%m/", blank=True)
    image_url = models.URLField(blank=True)

    is_active = models.BooleanField(default=True)
    position = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("position", "id")

    def __str__(self):
        return f"{self.product.name} — {self.option_label or self.sku}"

    def save(self, *args, **kwargs):
        if not self.sku:
            # Unique enough to satisfy the constraint before the options
            # are attached, which only happens after the row exists.
            self.sku = f"{slugify(self.product.name)[:40]}-{uuid4().hex[:8]}"
        super().save(*args, **kwargs)

    @property
    def option_label(self):
        """
        "White / 2 controllers / 1 TB", for lists and the cart.

        Ordered by attribute first. Value positions restart at 1 inside
        every attribute, so sorting on them alone shuffled the groups and
        the same variant read differently from one row to the next.
        """
        values = sorted(
            self.option_values.all(),
            key=lambda value: (value.attribute.position, value.position, value.name),
        )
        return " / ".join(value.name for value in values)

    @property
    def effective_price(self):
        return self.price if self.price is not None else self.product.price

    @property
    def effective_description(self):
        return self.description or self.product.description

    @property
    def display_image(self):
        """Falls back to the product picture when the variant has none."""
        if self.image:
            return self.image.url
        if self.image_url:
            return self.image_url
        return self.product.display_image

    @property
    def in_stock(self):
        return self.stock > 0


class SellerRating(models.Model):
    seller = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="seller_ratings_received",
    )
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="seller_ratings_given",
    )
    score = models.PositiveSmallIntegerField(
        choices=((1, "1"), (2, "2"), (3, "3"), (4, "4"), (5, "5"))
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-updated_at",)
        constraints = [
            models.UniqueConstraint(
                fields=("seller", "customer"),
                name="unique_customer_rating_per_seller",
            ),
            models.CheckConstraint(
                condition=models.Q(score__gte=1, score__lte=5),
                name="seller_rating_score_between_1_and_5",
            ),
            models.CheckConstraint(
                condition=~models.Q(seller=models.F("customer")),
                name="seller_cannot_rate_self",
            ),
        ]

    def __str__(self):
        return f"{self.customer} -> {self.seller}: {self.score}"


class Cart(models.Model):
    """
    One open cart per shopper.

    Prices are deliberately not copied here. A cart shows what the products
    cost right now; freezing a price is the job of an order, which is what
    the shopper actually agrees to pay.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="cart",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Cart of {self.user}"

    @property
    def item_count(self):
        """Total units, which is what the navbar badge shows."""
        return sum(item.quantity for item in self.items.all())

    @property
    def subtotal(self):
        return sum(
            (item.line_total for item in self.items.all()),
            Decimal("0.00"),
        )


class CartItem(models.Model):
    cart = models.ForeignKey(Cart, on_delete=models.CASCADE, related_name="items")
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name="cart_items",
    )
    # Null for products sold without options. Once a product has variants,
    # this is what was actually chosen, and its price and stock apply.
    variant = models.ForeignKey(
        ProductVariant,
        on_delete=models.CASCADE,
        related_name="cart_items",
        null=True,
        blank=True,
    )
    quantity = models.PositiveIntegerField(default=1)
    added_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ("-updated_at", "-id")
        constraints = [
            # One row per product *and* variant: two sizes of the same shoe
            # are two lines, but the same size twice raises the quantity.
            models.UniqueConstraint(
                fields=("cart", "product", "variant"),
                name="uniq_cart_product_variant",
            ),
            # Postgres treats NULLs as distinct, so the constraint above
            # would let a variant-less product be added twice.
            models.UniqueConstraint(
                fields=("cart", "product"),
                condition=Q(variant__isnull=True),
                name="uniq_cart_product_without_variant",
            ),
        ]

    def __str__(self):
        return f"{self.quantity} x {self.display_name}"

    @property
    def display_name(self):
        if self.variant is None:
            return self.product.name
        return f"{self.product.name} ({self.variant.option_label})"

    @property
    def unit_price(self):
        return self.variant.effective_price if self.variant else self.product.price

    @property
    def line_total(self):
        return self.unit_price * self.quantity

    @property
    def available_stock(self):
        return self.variant.stock if self.variant else self.product.stock

    @property
    def image(self):
        return (
            self.variant.display_image if self.variant else self.product.display_image
        )

    @property
    def has_stock_issue(self):
        """True when the shop can no longer fulfil what is in the cart."""
        if not self.product.is_active:
            return True
        if self.variant is not None and not self.variant.is_active:
            return True
        return self.quantity > self.available_stock
