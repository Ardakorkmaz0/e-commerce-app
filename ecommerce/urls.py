from django.urls import path
from . import views
from django.contrib.auth.views import LogoutView

app_name = 'ecommerce'

urlpatterns = [
	path('', views.home, name='home'),
    path('signin/', views.signin, name='signin'),
    path("signout/", LogoutView.as_view(), name="signout"),
]
