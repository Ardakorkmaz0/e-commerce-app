import 'package:ecommerce_mobile/features/auth/presentation/edit_profile_screen.dart';
import 'package:ecommerce_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:ecommerce_mobile/features/auth/presentation/sign_up_screen.dart';
import 'package:ecommerce_mobile/features/auth/presentation/splash_screen.dart';
import 'package:ecommerce_mobile/features/main/presentation/main_screen.dart';
import 'package:ecommerce_mobile/features/products/presentation/product_detail_screen.dart';
import 'package:ecommerce_mobile/features/seller/presentation/seller_product_form_screen.dart';
import 'package:ecommerce_mobile/features/seller/presentation/seller_products_screen.dart';
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
    // Slug rather than id, matching the backend's lookup_field.
    GoRoute(
      path: '/products/:slug',
      name: 'productDetail',
      builder: (context, state) => ProductDetailScreen(
        slug: state.pathParameters['slug']!,
      ),
    ),

    // Seller panel. Declared before /seller/:slug/edit so the literal
    // "new" segment is not swallowed by the parameter route.
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
      builder: (context, state) => SellerProductFormScreen(
        slug: state.pathParameters['slug'],
      ),
    ),
  ],
);
