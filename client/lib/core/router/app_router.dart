import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../presentation/features/auth/login_screen.dart';
import '../../presentation/features/auth/phone_verify_screen.dart';
import '../../presentation/features/home/home_shell.dart';
import '../../presentation/features/home/home_screen.dart';
import '../../presentation/features/onboarding/onboarding_screen.dart';
import '../../presentation/features/post/create_post_screen.dart';
import '../../presentation/features/post/post_detail_screen.dart';
import '../../presentation/features/profile/profile_screen.dart';
import '../../presentation/features/splash/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final appUser = ref.watch(currentAppUserProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/verify';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isSplash = state.matchedLocation == '/splash';

      final user = authState.valueOrNull;
      if (authState.isLoading) return null;

      // 未登录
      if (user == null) {
        if (loggingIn) return null;
        return '/login';
      }

      // 已登录 —— 检查资料是否填完（城市非空作为判断）
      final profile = appUser.valueOrNull;
      final profileIncomplete = profile != null &&
          (profile.city.isEmpty || profile.birthYear == null);

      if (profileIncomplete && !isOnboarding) return '/onboarding';
      if (!profileIncomplete && (isOnboarding || loggingIn || isSplash)) {
        return '/';
      }
      return null;
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
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
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
        path: '/post/create',
        builder: (_, __) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/post/:id',
        builder: (_, state) =>
            PostDetailScreen(postId: state.pathParameters['id']!),
      ),
    ],
  );
});
