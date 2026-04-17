# T5-04 地理搜索增强（Algolia GeoSearch）

## 目标
在发现页增加"附近"地理搜索入口，在发帖页增加"使用当前位置"按钮，让帖子携带经纬度以支持 Algolia aroundLatLng 搜索。

## 验收标准
1. `flutter analyze` 零错误
2. SearchQuery 支持 lat/lng/radiusMeters 地理搜索
3. DiscoverScreen 有"附近"PillTag 入口，支持 1/3/5/10/25km 半径选择
4. CreatePostScreen 有"使用当前位置"按钮（经纬度自动填入 PostDraft）
5. 所有新文案已加入 arb 文件（中英双语）

## Phase 分解

### Phase A: SearchQuery 增加地理搜索支持
- [x] SearchQuery 新增 lat/lng/radiusMeters 字段 + hasGeo getter
- [x] 更新 == / hashCode
- [x] searchResultsProvider 传 aroundLatLng / aroundRadius 到 Algolia SearchState
- [x] 空 query + hasGeo 时允许执行搜索（不再短路返回空列表）

### Phase B: "附近活动"入口（DiscoverScreen）
- [x] 复用已有 LocationService + 新增 currentLocationProvider (FutureProvider)
- [x] DiscoverScreen 添加 _nearbyMode / _radiusKm 状态
- [x] FilterBar 添加"附近"PillTag（点击切换附近模式）+ 关闭按钮
- [x] 附近模式下 watch currentLocationProvider → 用 Algolia geo search
- [x] 半径选择 bottom sheet（1/3/5/10/25 km）
- [x] 定位失败时显示提示 + 重试按钮

### Phase C: CreatePostScreen 地点选择优化
- [x] PostDraft 新增 locationLat / locationLng
- [x] publish() / updatePost() 写入 location.lat / location.lng 到 Firestore
- [x] GlassInput suffix 添加 my_location 按钮
- [x] _useCurrentLocation() 调用 LocationService 获取位置 + 自动填充

### Phase D: i18n
- [x] app_zh.arb: discover_nearby / discover_nearbyRadius / location_locating / location_permissionDenied / location_useCurrentLocation
- [x] app_en.arb: 同上英文版

## 依赖
- algolia_helper_flutter 1.6.0 原生支持 SearchState.aroundLatLng / aroundRadius
- geolocator 14.0.2 + geocoding 3.0.0 已在 pubspec.yaml
- LocationService 已存在于 data/services/location_service.dart
