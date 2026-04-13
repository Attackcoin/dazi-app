import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../presentation/features/auth/login_screen.dart';
import '../../presentation/features/auth/phone_verify_screen.dart';
import '../../presentation/features/checkin/checkin_screen.dart';
import '../../presentation/features/discover/discover_screen.dart';
import '../../presentation/features/home/home_shell.dart';
import '../../presentation/features/swipe/swipe_screen.dart';
import '../../presentation/features/messages/chat_screen.dart';
import '../../presentation/features/messages/messages_screen.dart';
import '../../presentation/features/onboarding/onboarding_screen.dart';
import '../../presentation/features/post/create_post_screen.dart';
import '../../presentation/features/post/post_detail_screen.dart';
import '../../presentation/features/profile/blocked_users_screen.dart';
import '../../presentation/features/profile/edit_profile_screen.dart';
import '../../presentation/features/profile/emergency_contacts_screen.dart';
import '../../presentation/features/profile/notifications_settings_screen.dart';
import '../../presentation/features/profile/privacy_settings_screen.dart';
import '../../presentation/features/profile/profile_screen.dart';
import '../../presentation/features/review/recap_card_screen.dart';
import '../../presentation/features/review/review_screen.dart';
import '../../presentation/features/search/search_screen.dart';
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
            builder: (_, __) => const SwipeScreen(),
          ),
          GoRoute(
            path: '/discover',
            builder: (_, __) => const DiscoverScreen(),
          ),
          GoRoute(
            path: '/messages',
            builder: (_, __) => const MessagesScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:chatId',
        builder: (_, state) =>
            ChatScreen(chatId: state.pathParameters['chatId']!),
      ),
      GoRoute(
        path: '/checkin/:matchId',
        builder: (_, state) =>
            CheckinScreen(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: '/review/:matchId',
        builder: (_, state) =>
            ReviewScreen(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: '/recap/:matchId',
        builder: (_, state) =>
            RecapCardScreen(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: '/settings/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/settings/emergency',
        builder: (_, __) => const EmergencyContactsScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, __) => const NotificationsSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (_, __) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: '/settings/blocked',
        builder: (_, __) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: '/user/:uid',
        builder: (_, state) =>
            ProfileScreen(uid: state.pathParameters['uid']!),
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
