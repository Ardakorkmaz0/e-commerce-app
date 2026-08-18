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


class IsVariantOwner(IsSeller):
    """
    Same rule, for rows that hang off a product instead of carrying a
    seller of their own. Without this, IsSeller looks for a seller_id that
    a variant does not have.
    """

    def has_object_permission(self, request, view, obj):
        return obj.product.seller_id == request.user.id
