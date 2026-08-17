from django.contrib import admin
from django.utils.html import format_html

from .models import (
    Attribute,
    AttributeValue,
    Category,
    Product,
    ProductVariant,
    SellerRating,
)


class AttributeValueInline(admin.TabularInline):
    model = AttributeValue
    extra = 3
    prepopulated_fields = {"slug": ("name",)}
    fields = ("name", "slug", "swatch_color", "position")


class ProductVariantInline(admin.TabularInline):
    """
    Variants are edited on the product they belong to, which is the only
    place the combination makes sense.
    """

    model = ProductVariant
    extra = 1
    filter_horizontal = ("option_values",)
    fields = (
        "option_values",
        "price",
        "stock",
        "image",
        "image_url",
        "description",
        "is_active",
        "position",
    )
    # Left empty, price falls back to the product's; the help text on the
    # model field says so.
    show_change_link = True


@admin.register(Attribute)
class AttributeAdmin(admin.ModelAdmin):
    list_display = ("name", "slug", "category_list", "value_list", "position")
    list_editable = ("position",)
    prepopulated_fields = {"slug": ("name",)}
    filter_horizontal = ("categories",)
    inlines = [AttributeValueInline]

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related("categories", "values")

    @admin.display(description="Shown in")
    def category_list(self, obj):
        names = [category.name for category in obj.categories.all()]
        return ", ".join(names) or "— (no category yet)"

    @admin.display(description="Values")
    def value_list(self, obj):
        names = [value.name for value in obj.values.all()]
        return ", ".join(names) or "—"


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ("name", "slug")
    prepopulated_fields = {"slug": ("name",)}
    search_fields = ("name",)


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    """
    Sellers are isolated from each other:

      superuser  sees and edits every product, and can reassign the seller
      seller     sees, edits and deletes only the products they own

    Isolation is enforced in three places on purpose. get_queryset hides
    other sellers' rows from every list and lookup, the has_*_permission
    hooks block someone who guesses an object URL directly, and save_model
    stamps ownership so a seller cannot create a listing for someone else.
    """

    # Declared at class level because Django's admin checks validate
    # list_editable against it; get_list_display extends it per user.
    list_display = ("thumbnail", "name", "category", "price", "stock", "is_active")
    list_display_links = ("name",)
    list_editable = ("price", "stock", "is_active")
    list_filter = ("category", "is_active")
    search_fields = ("name", "description")
    prepopulated_fields = {"slug": ("name",)}
    readonly_fields = ("image_preview",)
    filter_horizontal = ("attribute_values",)
    inlines = [ProductVariantInline]

    BASE_FIELDSETS = (
        (None, {"fields": ("name", "slug", "category", "description")}),
        ("Pricing and stock", {"fields": ("price", "stock", "is_active")}),
        (
            "Filters",
            {
                "fields": ("attribute_values",),
                "description": (
                    "Pick the values shoppers filter by, such as Brand: RTX "
                    "and Series: 3060. Manage the list under Attributes."
                ),
            },
        ),
        (
            "Image",
            {
                "fields": ("image", "image_url", "image_preview"),
                "description": (
                    "Upload a file or paste a link. If both are filled in, "
                    "the uploaded file is used."
                ),
            },
        ),
    )

    # ── Visibility ────────────────────────────────────────────────────

    def get_queryset(self, request):
        queryset = super().get_queryset(request)
        if request.user.is_superuser:
            return queryset
        return queryset.filter(seller=request.user)

    def get_list_display(self, request):
        # Only the superuser needs a seller column; a seller owns every row.
        if request.user.is_superuser:
            return self.list_display + ("seller",)
        return self.list_display

    def get_list_filter(self, request):
        if request.user.is_superuser:
            return self.list_filter + ("seller",)
        return self.list_filter

    def get_fieldsets(self, request, obj=None):
        if not request.user.is_superuser:
            return self.BASE_FIELDSETS

        # The superuser can hand a product to another seller.
        first, *rest = self.BASE_FIELDSETS
        name, options = first
        return (
            (name, {**options, "fields": (*options["fields"], "seller")}),
            *rest,
        )

    # ── Permissions ───────────────────────────────────────────────────

    def _owns(self, request, obj):
        """A seller may only touch their own listing."""
        if obj is None or request.user.is_superuser:
            return True
        return obj.seller_id == request.user.id

    def has_view_permission(self, request, obj=None):
        return self._owns(request, obj) and super().has_view_permission(request, obj)

    def has_change_permission(self, request, obj=None):
        return self._owns(request, obj) and super().has_change_permission(request, obj)

    def has_delete_permission(self, request, obj=None):
        return self._owns(request, obj) and super().has_delete_permission(request, obj)

    # ── Ownership ─────────────────────────────────────────────────────

    def save_model(self, request, obj, form, change):
        # A seller's new product is always their own; `seller` is not in
        # their form, so it could never be set from the request either.
        if not request.user.is_superuser and obj.seller_id is None:
            obj.seller = request.user
        super().save_model(request, obj, form, change)

    # ── Display helpers ───────────────────────────────────────────────

    @admin.display(description="Image")
    def thumbnail(self, obj):
        if not obj.display_image:
            return "—"
        return format_html(
            '<img src="{}" style="width:44px;height:44px;object-fit:cover;'
            'border-radius:6px;" />',
            obj.display_image,
        )

    @admin.display(description="Preview")
    def image_preview(self, obj):
        if not obj.display_image:
            return "No image yet."
        return format_html(
            '<img src="{}" style="max-width:220px;max-height:220px;'
            'object-fit:contain;border-radius:8px;" />',
            obj.display_image,
        )


@admin.register(SellerRating)
class SellerRatingAdmin(admin.ModelAdmin):
    list_display = ("seller", "customer", "score", "updated_at")
    list_filter = ("score", "updated_at")
    search_fields = (
        "seller__username",
        "seller__store_name",
        "customer__username",
    )
    readonly_fields = ("created_at", "updated_at")
