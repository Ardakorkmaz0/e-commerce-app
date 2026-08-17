from django.contrib import admin
from django.contrib.auth.admin import GroupAdmin, UserAdmin
from django.contrib.auth.models import Group

from .models import DeliveryAddress, User

SELLER_GROUP = "Sellers"


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    # Django's default list does not show groups, which makes it impossible
    # to tell at a glance who is a seller. These two columns fix that.
    list_display = (
        *UserAdmin.list_display,
        "store_name",
        "is_seller",
        "is_verified_seller",
        "group_names",
    )
    list_filter = (*UserAdmin.list_filter, "groups", "is_verified_seller")
    fieldsets = UserAdmin.fieldsets + (
        (
            "Seller profile",
            {"fields": ("store_name", "is_verified_seller")},
        ),
    )
    add_fieldsets = UserAdmin.add_fieldsets + (
        (
            "Seller profile",
            {"fields": ("store_name", "is_verified_seller")},
        ),
    )

    def get_queryset(self, request):
        # Without this the group columns would run one query per row.
        return super().get_queryset(request).prefetch_related("groups")

    @admin.display(boolean=True, description="Seller")
    def is_seller(self, obj):
        # Reads the prefetched groups instead of hitting the database again.
        return any(group.name == SELLER_GROUP for group in obj.groups.all())

    @admin.display(description="Groups")
    def group_names(self, obj):
        return ", ".join(group.name for group in obj.groups.all()) or "—"


@admin.register(DeliveryAddress)
class DeliveryAddressAdmin(admin.ModelAdmin):
    list_display = (
        "label",
        "recipient_name",
        "user",
        "city",
        "district",
        "is_default",
        "updated_at",
    )
    list_filter = ("is_default", "country_code")
    search_fields = (
        "label",
        "recipient_name",
        "phone_number",
        "city",
        "district",
        "user__username",
        "user__email",
    )
    autocomplete_fields = ("user",)
    readonly_fields = ("created_at", "updated_at")
    list_select_related = ("user",)
    date_hierarchy = "updated_at"


# Django's Group admin does not show who belongs to a group, so replace it.
admin.site.unregister(Group)


@admin.register(Group)
class CustomGroupAdmin(GroupAdmin):
    list_display = ("name", "member_count")
    readonly_fields = ("members",)

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related("user_set")

    @admin.display(description="Members")
    def member_count(self, obj):
        return obj.user_set.count()

    @admin.display(description="Members")
    def members(self, obj):
        usernames = list(obj.user_set.values_list("username", flat=True))
        if not usernames:
            return "No members yet."
        return ", ".join(usernames)
