from django.conf import settings
from django.db import models
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
    """One choice of an attribute: RTX and AMD are values of Brand."""

    attribute = models.ForeignKey(
        Attribute,
        on_delete=models.CASCADE,
        related_name="values",
    )
    name = models.CharField(max_length=80)
    slug = models.SlugField(max_length=90, blank=True)
    position = models.PositiveIntegerField(default=0)

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
        return self.stock > 0

    @property
    def display_image(self):
        """The uploaded file if there is one, otherwise the pasted link."""
        if self.image:
            return self.image.url
        return self.image_url
