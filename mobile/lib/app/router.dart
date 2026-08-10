import 'package:ecommerce_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:ecommerce_mobile/features/products/presentation/product_list_screen.dart';
import 'package:go_router/go_router.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/sign-in',
  routes: <RouteBase>[
    GoRoute(
      path: '/sign-in',
      name: 'signIn',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/products',
      name: 'products',
      builder: (context, state) => const ProductListScreen(),
    ),
  ],
);
