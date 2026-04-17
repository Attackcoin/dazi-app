import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/region_config.dart';
import '../models/venue.dart';
import 'auth_repository.dart';

final venueRepositoryProvider = Provider<VenueRepository>((ref) {
  final region = RegionConfig.resolveFunctionsRegion();
  return VenueRepository(
    firestore: ref.watch(firestoreProvider),
    functions: FirebaseFunctions.instanceFor(region: region),
  );
});

class VenueRepository {
  VenueRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  })  : _firestore = firestore,
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// 获取活跃的合作场地列表（Firestore 直读）。
  Stream<List<Venue>> watchVenues({int limit = 30}) {
    return _firestore
        .collection('venues')
        .where('isActive', isEqualTo: true)
        .orderBy('totalCheckins', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Venue.fromFirestore(d)).toList());
  }

  /// 获取单个场地详情。
  Stream<Venue?> watchVenue(String venueId) {
    return _firestore
        .collection('venues')
        .doc(venueId)
        .snapshots()
        .map((snap) => snap.exists ? Venue.fromFirestore(snap) : null);
  }

  /// 通过 Cloud Function 获取附近场地（支持分类过滤）。
  Future<List<Venue>> listNearbyVenues({String? category}) async {
    final callable = _functions.httpsCallable('listNearbyVenues');
    final resp = await callable.call<Map<dynamic, dynamic>>({
      if (category != null) 'category': category,
    });
    final venues = (resp.data['venues'] as List<dynamic>?) ?? [];
    return venues
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => Venue.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// 入驻申请。
  Future<String> registerVenue({
    required String name,
    String description = '',
    String category = '咖啡厅',
    required String address,
    double lat = 0,
    double lng = 0,
    String contactName = '',
    String contactPhone = '',
    List<String> perks = const [],
  }) async {
    final callable = _functions.httpsCallable('registerVenue');
    final resp = await callable.call<Map<dynamic, dynamic>>({
      'name': name,
      'description': description,
      'category': category,
      'address': address,
      'lat': lat,
      'lng': lng,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'perks': perks,
    });
    return resp.data['venueId'] as String;
  }

  /// 在场地签到。
  Future<List<String>> venueCheckin({
    required String venueId,
    String? matchId,
    String? postId,
  }) async {
    final callable = _functions.httpsCallable('venueCheckin');
    final resp = await callable.call<Map<dynamic, dynamic>>({
      'venueId': venueId,
      if (matchId != null) 'matchId': matchId,
      if (postId != null) 'postId': postId,
    });
    return List<String>.from(resp.data['perks'] as List? ?? []);
  }
}

// ─── Riverpod providers ─────────────────────────────

/// 合作场地列表流。
final venuesProvider = StreamProvider<List<Venue>>((ref) {
  return ref.watch(venueRepositoryProvider).watchVenues();
});

/// 单个场地详情流。
final venueProvider =
    StreamProvider.family<Venue?, String>((ref, venueId) {
  return ref.watch(venueRepositoryProvider).watchVenue(venueId);
});
