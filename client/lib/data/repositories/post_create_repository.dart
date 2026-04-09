import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import 'auth_repository.dart';

final postCreateRepositoryProvider = Provider<PostCreateRepository>((ref) {
  return PostCreateRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// 发布搭子帖子所需的所有字段。
class PostDraft {
  String category;
  String title;
  String description;
  List<String> imageUrls;
  DateTime? time;
  String locationName;
  String city;
  int totalSlots;
  int? maleQuota;
  int? femaleQuota;
  CostType costType;
  int depositAmount;
  bool isSocialAnxietyFriendly;
  bool isInstant;

  PostDraft({
    this.category = '',
    this.title = '',
    this.description = '',
    this.imageUrls = const [],
    this.time,
    this.locationName = '',
    this.city = '',
    this.totalSlots = 4,
    this.maleQuota,
    this.femaleQuota,
    this.costType = CostType.aa,
    this.depositAmount = 0,
    this.isSocialAnxietyFriendly = false,
    this.isInstant = false,
  });

  /// 校验草稿是否可发布。返回错误信息或 null。
  String? validate() {
    if (category.isEmpty) return '请选择分类';
    if (title.trim().isEmpty) return '请填写标题';
    if (time == null) return '请选择时间';
    if (time!.isBefore(DateTime.now())) return '活动时间必须在未来';
    if (locationName.trim().isEmpty) return '请填写地点';
    if (totalSlots < 2) return '人数不能少于 2 人';

    final maleQ = maleQuota ?? 0;
    final femaleQ = femaleQuota ?? 0;
    if (maleQ + femaleQ > totalSlots) {
      return '男女配额之和不能超过总人数';
    }
    return null;
  }
}

class PostCreateRepository {
  PostCreateRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// 上传图片到 Firebase Storage，返回下载 URL。
  Future<String> uploadImage(File file) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('未登录');

    final ref = FirebaseStorage.instance.ref(
      'posts/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}',
    );
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// 发布帖子。成功返回新文档 id。
  Future<String> publish(PostDraft draft) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('未登录');

    final doc = _firestore.collection('posts').doc();
    await doc.set({
      'userId': user.uid,
      'category': draft.category,
      'title': draft.title.trim(),
      'description': draft.description.trim(),
      'images': draft.imageUrls,
      'time': Timestamp.fromDate(draft.time!),
      'location': {
        'name': draft.locationName.trim(),
        'city': draft.city,
      },
      'totalSlots': draft.totalSlots,
      'minSlots': 2,
      'genderQuota': (draft.maleQuota == null && draft.femaleQuota == null)
          ? null
          : {
              'male': draft.maleQuota,
              'female': draft.femaleQuota,
            },
      'acceptedGender': {'male': 0, 'female': 0},
      'costType': draft.costType.value,
      'depositAmount': draft.depositAmount,
      'isInstant': draft.isInstant,
      'isSocialAnxietyFriendly': draft.isSocialAnxietyFriendly,
      'waitlist': <String>[],
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        draft.time!.add(const Duration(hours: 2)),
      ),
    });
    return doc.id;
  }
}
