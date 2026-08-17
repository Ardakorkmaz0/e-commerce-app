from django.http import Http404
from rest_framework import generics, status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import DeliveryAddress
from accounts.services import (
    DefaultAddressRequired,
    create_delivery_address,
    delete_delivery_address,
    update_delivery_address,
)

from .serializers import (
    CurrentUserSerializer,
    DeliveryAddressSerializer,
    RegisterSerializer,
    UpdateCurrentUserSerializer,
)


class RegisterView(generics.CreateAPIView):
    authentication_classes = []
    permission_classes = [AllowAny]
    serializer_class = RegisterSerializer


class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = CurrentUserSerializer(request.user)
        return Response(serializer.data)

    def patch(self, request):
        serializer = UpdateCurrentUserSerializer(
            request.user,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(CurrentUserSerializer(request.user).data)


class DeliveryAddressListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        addresses = request.user.delivery_addresses.all()
        return Response(DeliveryAddressSerializer(addresses, many=True).data)

    def post(self, request):
        serializer = DeliveryAddressSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        address = create_delivery_address(
            user=request.user,
            validated_data=serializer.validated_data,
        )
        return Response(
            DeliveryAddressSerializer(address).data,
            status=status.HTTP_201_CREATED,
        )


class DeliveryAddressDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def _get_address(self, request, address_id):
        try:
            return request.user.delivery_addresses.get(pk=address_id)
        except DeliveryAddress.DoesNotExist as error:
            raise Http404 from error

    def get(self, request, address_id):
        address = self._get_address(request, address_id)
        return Response(DeliveryAddressSerializer(address).data)

    def patch(self, request, address_id):
        current_address = self._get_address(request, address_id)
        serializer = DeliveryAddressSerializer(
            current_address,
            data=request.data,
            partial=True,
        )
        serializer.is_valid(raise_exception=True)

        try:
            address = update_delivery_address(
                user=request.user,
                address_id=address_id,
                validated_data=serializer.validated_data,
            )
        except DeliveryAddress.DoesNotExist as error:
            raise Http404 from error
        except DefaultAddressRequired as error:
            raise ValidationError({"is_default": [str(error)]}) from error

        return Response(DeliveryAddressSerializer(address).data)

    def delete(self, request, address_id):
        try:
            delete_delivery_address(user=request.user, address_id=address_id)
        except DeliveryAddress.DoesNotExist as error:
            raise Http404 from error
        return Response(status=status.HTTP_204_NO_CONTENT)


class LogoutView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        refresh_token = request.data.get("refresh")
        if not isinstance(refresh_token, str) or not refresh_token:
            return Response(
                {"refresh": ["This field is required."]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            RefreshToken(refresh_token).blacklist()
        except TokenError:
            return Response(
                {"refresh": ["Token is invalid or expired."]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(status=status.HTTP_204_NO_CONTENT)
