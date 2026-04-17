import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../presentation/features/auth/login_screen.dart';
import '../../presentation/features/auth/phone_verify_screen.dart';
import '../../presentation/features/auth/set_password_screen.dart';
import '../../presentation/features/checkin/checkin_screen.dart';
import '../../presentation/features/circles/circle_detail_screen.dart';
import '../../presentation/features/circles/circles_screen.dart';
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
import '../../presentation/features/venues/venue_detail_screen.dart';
import '../../presentation/features/venues/venues_screen.dart';
import '../../presentation/features/voice/voice_room_detail_screen.dart';
import '../../presentation/features/voice/voice_rooms_screen.dart';

/// 将 Riverpod 的 auth / profile 变化桥接到 GoRouter 的 refreshListenable，
/// 避免每次 auth 状态变化都重建 GoRouter 实例（导致导航栈丢失）。
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    _subs = [
      ref.listen(authStateProvider, (_, __) => notifyListeners()),
      ref.listen(currentAppUserProvider, (_, __) => notifyListeners()),
    ];
  }

  late final List<ProviderSubscription<Object?>> _subs;

  @override
  void dispose() {
    for (final s in _subs) {
      s.close();
    }
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/verify';
      final isOnboarding = state.matchedLocation == '/onboarding';
      final isSplash = state.matchedLocation == '/splash';

      final authState = ref.read(authStateProvider);
      final user = authState.valueOrNull;
      if (authState.isLoading) return null;

      // 未登录
      if (user == null) {
        if (loggingIn) return null;
        return '/login';
      }

      // 已登录 —— 检查资料是否填完（城市非空作为判断）
      final appUser = ref.read(currentAppUserProvider);
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
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const SwipeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/discover',
              builder: (_, __) => const DiscoverScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/messages',
              builder: (_, __) => const MessagesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/chat/:chatId',
        pageBuilder: (_, state) => _slideUp(
          state,
          ChatScreen(chatId: state.pathParameters['chatId']!),
        ),
      ),
      GoRoute(
        path: '/checkin/:matchId',
        pageBuilder: (_, state) => _slideUp(
          state,
          CheckinScreen(matchId: state.pathParameters['matchId']!),
        ),
      ),
      GoRoute(
        path: '/review/:matchId',
        pageBuilder: (_, state) => _slideUp(
          state,
          ReviewScreen(matchId: state.pathParameters['matchId']!),
        ),
      ),
      GoRoute(
        path: '/recap/:matchId',
        pageBuilder: (_, state) => _fadeScale(
          state,
          RecapCardScreen(matchId: state.pathParameters['matchId']!),
        ),
      ),
      GoRoute(
        path: '/settings/edit',
        pageBuilder: (_, state) => _slideUp(state, const EditProfileScreen()),
      ),
      GoRoute(
        path: '/settings/emergency',
        pageBuilder: (_, state) =>
            _slideUp(state, const EmergencyContactsScreen()),
      ),
      GoRoute(
        path: '/settings/notifications',
        pageBuilder: (_, state) =>
            _slideUp(state, const NotificationsSettingsScreen()),
      ),
      GoRoute(
        path: '/settings/privacy',
        pageBuilder: (_, state) =>
            _slideUp(state, const PrivacySettingsScreen()),
      ),
      GoRoute(
        path: '/settings/blocked',
        pageBuilder: (_, state) =>
            _slideUp(state, const BlockedUsersScreen()),
      ),
      GoRoute(
        path: '/settings/password',
        pageBuilder: (_, state) =>
            _slideUp(state, const SetPasswordScreen()),
      ),
      GoRoute(
        path: '/circles',
        pageBuilder: (_, state) => _slideUp(state, const CirclesScreen()),
      ),
      GoRoute(
        path: '/circle/:circleId',
        pageBuilder: (_, state) => _slideUp(
          state,
          CircleDetailScreen(circleId: state.pathParameters['circleId']!),
        ),
      ),
      GoRoute(
        path: '/venues',
        pageBuilder: (_, state) => _slideUp(state, const VenuesScreen()),
      ),
      GoRoute(
        path: '/venue/:venueId',
        pageBuilder: (_, state) => _slideUp(
          state,
          VenueDetailScreen(venueId: state.pathParameters['venueId']!),
        ),
      ),
      GoRoute(
        path: '/voice',
        pageBuilder: (_, state) => _slideUp(state, const VoiceRoomsScreen()),
      ),
      GoRoute(
        path: '/voice/:roomId',
        pageBuilder: (_, state) => _slideUp(
          state,
          VoiceRoomDetailScreen(roomId: state.pathParameters['roomId']!),
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, state) => _fadeScale(state, const SearchScreen()),
      ),
      GoRoute(
        path: '/user/:uid',
        pageBuilder: (_, state) => _slideUp(
          state,
          ProfileScreen(uid: state.pathParameters['uid']!),
        ),
      ),
      GoRoute(
        path: '/post/create',
        pageBuilder: (_, state) =>
            _slideUp(state, const CreatePostScreen()),
      ),
      GoRoute(
        path: '/post/:id',
        pageBuilder: (_, state) => _slideUp(
          state,
          PostDetailScreen(postId: state.pathParameters['id']!),
        ),
      ),
    ],
  );
});

// ── 页面转场动画 ──────────────────────────────────────────

/// 从底部滑入 —— 详情页、设置页、聊天页等二级页面。
CustomTransitionPage<void> _slideUp(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (_, animation, __, child) {
      final slide = Tween(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

/// 缩放 + 淡入 —— 搜索页、回忆卡等弹出式页面。
CustomTransitionPage<void> _fadeScale(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (_, animation, __, child) {
      final scale = Tween(begin: 0.95, end: 1.0)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}
