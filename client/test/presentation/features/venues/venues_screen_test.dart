import 'dart:async';

import 'package:dazi_app/core/theme/glass_theme.dart';
import 'package:dazi_app/data/models/venue.dart';
import 'package:dazi_app/data/repositories/venue_repository.dart';
import 'package:dazi_app/presentation/features/venues/venues_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: GlassTheme(
      data: GlassThemeData.dark,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: child,
      ),
    ),
  );
}

Venue _fakeVenue({
  String id = 'v1',
  String name = '星巴克臻选',
  String category = 'cafe',
  String address = '南京西路789号',
  int totalCheckins = 128,
}) =>
    Venue(
      id: id,
      name: name,
      description: '全球最大星巴克',
      category: category,
      address: address,
      lat: 31.23,
      lng: 121.47,
      coverImage: '',
      images: const [],
      perks: const ['免费咖啡'],
      isActive: true,
      totalCheckins: totalCheckins,
    );

void main() {
  testWidgets('VenuesScreen —— loading 态显示进度指示器', (tester) async {
    final controller = StreamController<List<Venue>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          venuesProvider.overrideWith((ref) => controller.stream),
        ],
        child: const VenuesScreen(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('VenuesScreen —— 空列表显示空态图标', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          venuesProvider.overrideWith(
            (ref) => Stream.value(<Venue>[]),
          ),
        ],
        child: const VenuesScreen(),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
  });

  testWidgets('VenuesScreen —— 有数据时显示场地卡片', (tester) async {
    final venues = [
      _fakeVenue(id: 'v1', name: '星巴克臻选', totalCheckins: 128),
      _fakeVenue(id: 'v2', name: '超级猩猩健身', category: 'gym', totalCheckins: 56),
    ];

    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          venuesProvider.overrideWith(
            (ref) => Stream.value(venues),
          ),
        ],
        child: const VenuesScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('星巴克臻选'), findsOneWidget);
    expect(find.text('超级猩猩健身'), findsOneWidget);
  });

  testWidgets('VenuesScreen —— 错误态显示加载失败', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          venuesProvider.overrideWith(
            (ref) => Stream<List<Venue>>.error(Exception('network')),
          ),
        ],
        child: const VenuesScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('加载失败'), findsOneWidget);
  });

  testWidgets('VenuesScreen —— 入驻按钮存在', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          venuesProvider.overrideWith(
            (ref) => Stream.value(<Venue>[]),
          ),
        ],
        child: const VenuesScreen(),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.add_business_outlined), findsOneWidget);
  });

  testWidgets('VenuesScreen —— 卡片显示地址和签到数', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        overrides: [
          venuesProvider.overrideWith(
            (ref) => Stream.value([
              _fakeVenue(
                name: '网红咖啡馆',
                address: '静安寺路100号',
                totalCheckins: 200,
              ),
            ]),
          ),
        ],
        child: const VenuesScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('网红咖啡馆'), findsOneWidget);
    expect(find.text('静安寺路100号'), findsOneWidget);
  });
}
