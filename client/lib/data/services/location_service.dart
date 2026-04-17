import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// 定位结果 —— 城市名 + 经纬度。
class LocationResult {
  const LocationResult({required this.city, required this.lat, required this.lng});
  final String city;
  final double lat;
  final double lng;
}

/// 定位服务：获取当前位置 → 反向地理编码得到城市名。
/// 全球可用，不限于中国。
final locationServiceProvider = Provider<LocationService>((_) => LocationService());

/// 当前位置 FutureProvider —— lazy 获取一次用户位置（含经纬度+城市名）。
///
/// 返回 null 表示定位失败（权限拒绝 / GPS 关闭 / 超时等）。
/// 使用 `ref.invalidate(currentLocationProvider)` 可触发重新定位。
final currentLocationProvider = FutureProvider<LocationResult?>((ref) {
  return ref.watch(locationServiceProvider).getCurrentCity();
});

class LocationService {
  /// 获取当前城市。
  /// 返回 null 表示定位失败（权限拒绝、GPS 关闭等）。
  Future<LocationResult?> getCurrentCity() async {
    // 1. 检查定位服务是否开启
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    // 2. 检查 / 请求权限
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    // 3. 获取经纬度
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low, // 城市级别够了，省电
        timeLimit: Duration(seconds: 10),
      ),
    );

    // 4. 反向地理编码 → 城市名
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isEmpty) return null;

    final place = placemarks.first;
    // 优先取 locality（城市），没有就取 subAdministrativeArea / administrativeArea
    final city = place.locality?.isNotEmpty == true
        ? place.locality!
        : place.subAdministrativeArea?.isNotEmpty == true
            ? place.subAdministrativeArea!
            : place.administrativeArea ?? '';

    if (city.isEmpty) return null;

    return LocationResult(
      city: city,
      lat: position.latitude,
      lng: position.longitude,
    );
  }
}
