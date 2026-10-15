// Copyright (c) 2026 P Om Shiva. All rights reserved.
// AquaAware: unauthorised copying, modification or distribution of this file,
// by any means, is prohibited without the author's written permission. See LICENSE.

import 'dart:math' as math;

/// A plain latitude/longitude pair used by the data layer (the map layer
/// converts to `LatLng` at the edge so models stay platform-free).
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;

  Map<String, Object?> toJson() => {'lat': lat, 'lng': lng};
  factory GeoPoint.fromJson(Map<String, Object?> j) =>
      GeoPoint((j['lat']! as num).toDouble(), (j['lng']! as num).toDouble());
}

abstract final class Geo {
  /// Great-circle distance in metres (Haversine). The previous version
  /// compared raw degree differences, which is wrong by up to ~10% at
  /// Pondicherry's latitude and meaningless as a "100 m" radius.
  static double distanceMeters(GeoPoint a, GeoPoint b) {
    const r = 6371000.0;
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  static String describeDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
  }

  /// Rough city-traffic ETA for a collector on a two-wheeler (~18 km/h).
  static int etaMinutes(double meters) => math.max(3, (meters / 300).round());
}
