"""
Creates the "Sellers" group: a staff role one level below superuser.

Permission levels in this project:

    superuser      the Django admin: everything, including users and groups
    Sellers        their own products, through /seller in the web app
    regular user   shopping only

Sellers are NOT Django staff. They never see the admin, so there is no
surface on which they could reach another person's account data. The
group's model permissions exist for the API layer, which checks group
membership rather than admin access.

Usage:
    python manage.py create_seller_group
    python manage.py create_seller_group --user alice
"""

from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group, Permission
from django.core.management.base import BaseCommand, CommandError

GROUP_NAME = "Sellers"

# (app_label, model, [actions])
PERMISSION_MAP = [
    # Full control over products — but ProductAdmin narrows this to the
    # seller's own listings, so "delete_product" never reaches someone
    # else's row.
    ("ecommerce", "product", ["add", "change", "delete", "view"]),
    # Categories are shared by every seller: renaming or deleting one would
    # change other people's listings, so sellers may only add and view.
    ("ecommerce", "category", ["add", "view"]),
]


class Command(BaseCommand):
    help = "Creates or updates the Sellers group and optionally adds a user to it."

    def add_arguments(self, parser):
        parser.add_argument(
            "--user",
            dest="username",
            help="Username to add to the group and mark as staff.",
        )

    def handle(self, *args, **options):
        group, created = Group.objects.get_or_create(name=GROUP_NAME)

        permissions = []
        for app_label, model, actions in PERMISSION_MAP:
            for action in actions:
                codename = f"{action}_{model}"
                try:
                    permissions.append(
                        Permission.objects.get(
                            codename=codename,
                            content_type__app_label=app_label,
                        )
                    )
                except Permission.DoesNotExist as error:
                    raise CommandError(
                        f"Permission {app_label}.{codename} does not exist. "
                        "Run migrate first."
                    ) from error

        # set() replaces the whole list, so re-running the command also
        # removes permissions that were dropped from PERMISSION_MAP.
        group.permissions.set(permissions)

        self.stdout.write(
            self.style.SUCCESS(
                f"{'Created' if created else 'Updated'} group "
                f"'{GROUP_NAME}' with {len(permissions)} permissions."
            )
        )
        for permission in permissions:
            self.stdout.write(f"  - {permission.codename}")

        username = options.get("username")
        if not username:
            self.stdout.write(
                "\nTo make someone a seller: assign them to the "
                f"'{GROUP_NAME}' group in the admin and tick 'Staff status', "
                "or re-run this command with --user <username>."
            )
            return

        User = get_user_model()
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist as error:
            raise CommandError(f"User '{username}' was not found.") from error

        if user.is_superuser:
            raise CommandError(
                f"'{username}' is a superuser and already has full access."
            )

        # Sellers work in the storefront's seller panel, not the Django
        # admin, so staff access is explicitly withdrawn here.
        if user.is_staff:
            user.is_staff = False
            user.save(update_fields=["is_staff"])
            self.stdout.write(
                self.style.WARNING(f"Removed Django admin access from '{username}'.")
            )

        user.groups.add(group)

        self.stdout.write(
            self.style.SUCCESS(
                f"\n'{username}' is now a seller. They manage products at "
                "/seller in the web app, and cannot open the Django admin."
            )
        )
