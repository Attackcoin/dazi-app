import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'core/locale/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/glass_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/services/push_notification_service.dart';

/// 主题模式 Provider — 默认跟随系统。
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

class DaziApp extends ConsumerStatefulWidget {
  const DaziApp({super.key});

  @override
  ConsumerState<DaziApp> createState() => _DaziAppState();
}

/// 根据实际 brightness 注入对应 GlassThemeData。
class _GlassThemeWrapper extends StatelessWidget {
  const _GlassThemeWrapper({required this.themeMode, required this.child});

  final ThemeMode themeMode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };

    return GlassTheme(
      data: isDark ? GlassThemeData.dark : GlassThemeData.light,
      child: child,
    );
  }
}

class _DaziAppState extends ConsumerState<DaziApp> {
  bool _fcmInitialized = false;

  @override
  void initState() {
    super.initState();
    _restoreLocale();
  }

  Future<void> _restoreLocale() async {
    final saved = await LocalePersistence.load();
    if (mounted && saved != null) {
      ref.read(localeProvider.notifier).state = saved;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    // 登录后初始化 FCM
    ref.listen(authStateProvider, (prev, next) {
      final user = next.valueOrNull;
      if (user != null && !_fcmInitialized) {
        _fcmInitialized = true;
        ref.read(pushNotificationServiceProvider).initialize();
      }
      if (user == null) {
        _fcmInitialized = false;
      }
    });

    return _GlassThemeWrapper(
      themeMode: themeMode,
      child: MaterialApp.router(
        title: 'Dazi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }
}
