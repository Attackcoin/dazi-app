// Firebase Auth Emulator SMS 验证码读取 helper。
//
// Firebase Auth emulator 不会真发短信，发送 phone code 后会把生成的 code 存到
// 内部列表，可通过 REST 端点读取：
//   GET http://127.0.0.1:9099/emulator/v1/projects/{projectId}/verificationCodes
//
// 返回示例：
//   {
//     "verificationCodes": [
//       {"phoneNumber": "+8613800000001", "sessionInfo": "...", "code": "123456"}
//     ]
//   }
//
// 用法（在 J1 中）：
//   final code = await fetchLatestSmsCode('dazi-dev', '+8613800000001');

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Auth emulator 的 host:port（与 emulator_setup.dart 对齐）。
const String _authEmulatorBase = 'http://127.0.0.1:9099';

/// 读取指定 projectId 下、指定手机号的最新一条 verification code。
///
/// - [projectId] 必须与 Firebase 项目一致（可由 DefaultFirebaseOptions.currentPlatform.projectId 传入）
/// - [phoneNumber] 必须是 E.164 格式，例如 `+8613800000001`
///
/// 异常：
/// - 空列表 → [StateError]
/// - HTTP 非 200 → [Exception]（带状态码和 body 摘要）
Future<String> fetchLatestSmsCode(String projectId, String phoneNumber) async {
  final uri = Uri.parse(
    '$_authEmulatorBase/emulator/v1/projects/$projectId/verificationCodes',
  );
  final resp = await http.get(uri);
  if (resp.statusCode != 200) {
    throw Exception(
      'fetchLatestSmsCode: HTTP ${resp.statusCode} from $uri — body=${resp.body}',
    );
  }

  final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
  final list = (decoded['verificationCodes'] as List<dynamic>? ?? const []);

  // 按手机号过滤；list 末尾视为最新
  final matching = list
      .cast<Map<String, dynamic>>()
      .where((e) => e['phoneNumber'] == phoneNumber)
      .toList();

  if (matching.isEmpty) {
    throw StateError('No verification code yet for $phoneNumber');
  }

  final code = matching.last['code'] as String?;
  if (code == null || code.isEmpty) {
    throw StateError(
      'Verification code entry for $phoneNumber has empty code field',
    );
  }
  return code;
}
