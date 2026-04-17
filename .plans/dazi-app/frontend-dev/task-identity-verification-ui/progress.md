# T5-01 身份验证 UI — 进度

## 2026-04-17

### Phase C: i18n 文案 -- DONE
- app_zh.arb: +7 keys (profile_verified, profile_verifiedA11y, profile_verifyIdentity, profile_verifyBenefits, profile_verifyStart, profile_verifyComingSoon, post_verifiedPublisher, discover_verifiedOnly)
- app_en.arb: +8 keys (same)
- `flutter gen-l10n` PASS

### Phase A: 验证徽章展示 -- DONE
- profile_header.dart: 新增 `_VerifiedBadge` widget，verificationLevel >= 2 时在名字行显示
- post_detail_screen.dart: `_PublisherRow` 名字旁增加 `_VerifiedIcon`，verificationLevel >= 2 时显示
- PostCard: 跳过（Post model 无 publisherVerificationLevel）

### Phase B: 验证流程入口 -- DONE
- profile_screen.dart: 新增 `_VerifyIdentityPrompt` card（isSelf + level < 2 时在 MetaSection 下方显示）
- profile_screen.dart: 新增 `_showVerifySheet` BottomSheet（说明 + "开始验证"按钮 → SnackBar "功能即将上线"）
- discover_screen.dart: _FilterBar 新增"已验证"PillTag（UI placeholder，实际筛选待 Post denorm 字段）

### 验证
- `flutter analyze`: 0 errors (4 pre-existing info warnings in unrelated files)
- `flutter gen-l10n`: PASS
