import 'package:ecommerce_mobile/features/auth/presentation/edit_profile_screen.dart';
import 'package:ecommerce_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:ecommerce_mobile/features/auth/presentation/sign_up_screen.dart';
import 'package:ecommerce_mobile/features/main/presentation/main_screen.dart';
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
  ],
);
