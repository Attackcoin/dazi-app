import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../presentation/features/auth/login_screen.dart';
import '../../presentation/features/auth/phone_verify_screen.dart';
import '../../presentation/features/home/home_shell.dart';
import '../../presentation/features/home/home_screen.dart';
import '../../presentation/features/post/post_detail_screen.dart';
import '../../presentation/features/profile/profile_screen.dart';
import '../../presentation/features/splash/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/verify';
      final isSplash = state.matchedLocation == '/splash';

      return authState.when(
        data: (user) {
          if (isSplash) return user == null ? '/login' : '/';
          if (user == null && !loggingIn) return '/login';
          if (user != null && loggingIn) return '/';
          return null;
        },
        loading: () => null,
        error: (_, __) => '/login',
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/verify',
        builder: (_, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return PhoneVerifyScreen(phone: phone);
        },
      ),
      ShellRoute(
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/post/:id',
        builder: (_, state) =>
            PostDetailScreen(postId: state.pathParameters['id']!),
      ),
    ],
  );
});
