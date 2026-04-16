// Firestore Emulator admin helper —— 通过 REST + Bearer owner 绕过 rules。
//
// 用途：E2E 测试需要把某些字段强行设到只能由 Cloud Functions 写入的集合
// （例如 matches.checkinWindowOpen）。直接走 SDK 会被 rules 拒。Firebase
// emulator 提供 `Authorization: Bearer owner` 跳过 rules 的特殊通道。
//
// 仅限 emulator 使用 —— 真实项目永远拒绝匿名 owner 头。
//
// 参考：https://firebase.google.com/docs/emulator-suite/connect_firestore#admin_credentials

import 'dart:convert';

import 'package:http/http.dart' as http;

const String _firestoreEmulatorBase = 'http://127.0.0.1:8080';

/// Patch 一个 Firestore 文档的若干字段，绕过 security rules。
///
/// [docPath] 形如 `matches/abc123`（不带 `databases/(default)/documents/` 前缀）。
/// [fields] 的值需要符合 Firestore REST 的 typed-value 编码：
///
///   bool   →  `{'booleanValue': true}`
///   int    →  `{'integerValue': '5'}`
///   double →  `{'doubleValue': 1.23}`
///   string →  `{'stringValue': 'foo'}`
///   ts     →  `{'timestampValue': '2026-01-01T00:00:00Z'}`
///
/// 详见 helper 内 [encodeBool]/[encodeTimestamp] 等便捷方法。
Future<void> adminPatchDoc({
  required String projectId,
  required String docPath,
  required Map<String, Map<String, dynamic>> fields,
}) async {
  final mask = fields.keys
      .map((k) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(k)}')
      .join('&');
  final uri = Uri.parse(
    '$_firestoreEmulatorBase/v1/projects/$projectId/databases/(default)'
    '/documents/$docPath?$mask',
  );
  final resp = await http.patch(
    uri,
    headers: {
      'Authorization': 'Bearer owner',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'fields': fields}),
  );
  if (resp.statusCode != 200) {
    throw Exception(
      'adminPatchDoc HTTP ${resp.statusCode} — body=${resp.body}',
    );
  }
}

Map<String, dynamic> encodeBool(bool v) => {'booleanValue': v};
Map<String, dynamic> encodeString(String v) => {'stringValue': v};
Map<String, dynamic> encodeTimestamp(DateTime v) =>
    {'timestampValue': v.toUtc().toIso8601String()};
