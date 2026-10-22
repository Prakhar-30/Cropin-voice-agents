import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  /// Great-circle distance in kilometres.
  double distanceKm(GeoPoint o) {
    const r = 6371.0;
    final dLat = _rad(o.lat - lat);
    final dLng = _rad(o.lng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat)) * math.cos(_rad(o.lat)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(a)));
  }

  static double _rad(double d) => d * math.pi / 180;
}

class LocationFix {
  const LocationFix(this.point, this.source);
  final GeoPoint point;

  /// 'gps', 'last-known' or 'demo'
  final String source;
  bool get isDemo => source == 'demo';
}

/// GPS works offline. When no fix is available, or the phone is far away from
/// the demo plots, a demo location in BTM Layout (Bengaluru) is used instead.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const demoPoint = GeoPoint(12.9166, 77.6101); // BTM Layout, Bengaluru

  /// 'auto' (GPS, demo fallback), 'gps' or 'demo'
  String mode = 'auto';
  LocationFix? last;

  Future<LocationFix> current({List<GeoPoint> nearTo = const [], double maxKm = 60}) async {
    if (mode == 'demo') return last = const LocationFix(demoPoint, 'demo');
    LocationFix? fix;
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
          try {
            final p = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 8),
              ),
            );
            fix = LocationFix(GeoPoint(p.latitude, p.longitude), 'gps');
          } catch (_) {
            final p = await Geolocator.getLastKnownPosition();
            if (p != null) fix = LocationFix(GeoPoint(p.latitude, p.longitude), 'last-known');
          }
        }
      }
    } catch (_) {
      fix = null;
    }
    if (fix == null) return last = const LocationFix(demoPoint, 'demo');
    if (mode == 'auto' && nearTo.isNotEmpty) {
      final nearest = nearTo.map(fix.point.distanceKm).reduce(math.min);
      if (nearest > maxKm) return last = const LocationFix(demoPoint, 'demo');
    }
    return last = fix;
  }
}
