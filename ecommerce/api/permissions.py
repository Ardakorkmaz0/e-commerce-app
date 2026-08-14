from rest_framework import permissions

SELLER_GROUP = "Sellers"


class IsSeller(permissions.BasePermission):
    """
    Allows access to members of the Sellers group.

    Deliberately does not look at is_staff: sellers manage their catalog
    through the storefront's own seller panel, never the Django admin.
    """

    message = "You need a seller account to do this."

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.groups.filter(name=SELLER_GROUP).exists()
        )

    def has_object_permission(self, request, view, obj):
        # A seller may only touch their own listing.
        return obj.seller_id == request.user.id
