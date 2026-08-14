from django.contrib import admin
from django.contrib.auth.admin import GroupAdmin, UserAdmin
from django.contrib.auth.models import Group

from .models import User

SELLER_GROUP = "Sellers"


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    # Django's default list does not show groups, which makes it impossible
    # to tell at a glance who is a seller. These two columns fix that.
    list_display = (*UserAdmin.list_display, "is_seller", "group_names")
    list_filter = (*UserAdmin.list_filter, "groups")

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
