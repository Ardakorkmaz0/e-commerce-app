import 'package:ecommerce_mobile/features/addresses/data/models/delivery_address_model.dart';
import 'package:ecommerce_mobile/features/addresses/presentation/address_form_screen.dart';
import 'package:ecommerce_mobile/features/addresses/presentation/address_list_screen.dart';
import 'package:ecommerce_mobile/features/auth/presentation/edit_profile_screen.dart';
import 'package:ecommerce_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:ecommerce_mobile/features/auth/presentation/sign_up_screen.dart';
import 'package:ecommerce_mobile/features/auth/presentation/splash_screen.dart';
import 'package:ecommerce_mobile/features/checkout/presentation/checkout_screen.dart';
import 'package:ecommerce_mobile/features/orders/presentation/order_detail_screen.dart';
import 'package:ecommerce_mobile/features/orders/presentation/orders_screen.dart';
import 'package:ecommerce_mobile/features/orders/presentation/seller_orders_screen.dart';
import 'package:ecommerce_mobile/features/main/presentation/main_screen.dart';
import 'package:ecommerce_mobile/features/payments/presentation/add_card_screen.dart';
import 'package:ecommerce_mobile/features/payments/presentation/payment_methods_screen.dart';
import 'package:ecommerce_mobile/features/products/presentation/product_detail_screen.dart';
import 'package:ecommerce_mobile/features/seller/presentation/seller_product_form_screen.dart';
import 'package:ecommerce_mobile/features/seller/presentation/seller_products_screen.dart';
import 'package:ecommerce_mobile/features/seller/presentation/seller_variants_screen.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  // Starts on the gate, which decides between the store and the sign-in
  // screen once the stored session has been checked.
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/sign-in',
      name: 'signIn',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/sign-up',
      name: 'signUp',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/main',
      name: 'main',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/profile/edit',
      name: 'editProfile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/profile/addresses',
      name: 'addresses',
      builder: (context, state) => const AddressListScreen(),
    ),
    GoRoute(
      path: '/profile/addresses/new',
      name: 'addressNew',
      builder: (context, state) => const AddressFormScreen(),
    ),
    // Declared after /new so the literal segment is not captured as an id.
    // The address travels in `extra` because the list already has it; the
    // screen falls back to the add form if it arrives empty (deep link).
    GoRoute(
      path: '/profile/addresses/:id/edit',
      name: 'addressEdit',
      builder: (context, state) =>
          AddressFormScreen(address: state.extra as DeliveryAddress?),
    ),
    GoRoute(
      path: '/profile/payment-methods',
      name: 'paymentMethods',
      builder: (context, state) => const PaymentMethodsScreen(),
    ),
    GoRoute(
      path: '/profile/payment-methods/new',
      name: 'paymentMethodNew',
      builder: (context, state) => const AddCardScreen(),
    ),
    // Slug rather than id, matching the backend's lookup_field.
    GoRoute(
      path: '/products/:slug',
      name: 'productDetail',
      builder: (context, state) =>
          ProductDetailScreen(slug: state.pathParameters['slug']!),
    ),

    // Seller panel. Declared before /seller/:slug/edit so the literal
    // "new" segment is not swallowed by the parameter route.
    GoRoute(
      path: '/checkout',
      name: 'checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),

    GoRoute(
      path: '/myorders',
      name: 'orders',
      builder: (context, state) => const OrdersScreen(),
    ),
    GoRoute(
      path: '/myorders/:number',
      name: 'orderDetail',
      builder: (context, state) => OrderDetailScreen(
        orderNumber: state.pathParameters['number']!,
        justPlaced: state.uri.queryParameters['placed'] == '1',
      ),
    ),

    // Declared before /seller/:slug/edit so the literal "orders" segment
    // is not swallowed by the parameter route.
    GoRoute(
      path: '/seller/orders',
      name: 'sellerOrders',
      builder: (context, state) => const SellerOrdersScreen(),
    ),
    GoRoute(
      path: '/seller',
      name: 'sellerProducts',
      builder: (context, state) => const SellerProductsScreen(),
    ),
    GoRoute(
      path: '/seller/new',
      name: 'sellerProductNew',
      builder: (context, state) => const SellerProductFormScreen(),
    ),
    GoRoute(
      path: '/seller/:slug/edit',
      name: 'sellerProductEdit',
      builder: (context, state) =>
          SellerProductFormScreen(slug: state.pathParameters['slug']),
    ),
    GoRoute(
      path: '/seller/:slug/variants',
      name: 'sellerProductVariants',
      builder: (context, state) =>
          SellerVariantsScreen(slug: state.pathParameters['slug']!),
    ),
  ],
);
