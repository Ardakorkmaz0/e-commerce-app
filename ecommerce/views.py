from django.contrib.auth import login
from django.contrib.auth.decorators import login_not_required
from django.contrib.auth.forms import AuthenticationForm
from django.shortcuts import redirect, render


def home(request):
    return render(request, "ecommerce/home.html")


@login_not_required
def signin(request):
    if request.user.is_authenticated:
        return redirect("ecommerce:home")

    form = AuthenticationForm(
        request=request,
        data=request.POST if request.method == "POST" else None,
    )

    if request.method == "POST" and form.is_valid():
        login(request, form.get_user())

        if not request.POST.get("remember_me"):
            request.session.set_expiry(0)

        return redirect("ecommerce:home")

    return render(request, "ecommerce/signin.html", {"form": form})
