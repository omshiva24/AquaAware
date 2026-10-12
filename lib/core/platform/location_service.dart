import 'package:geolocator/geolocator.dart';

import '../utils/geo.dart';

enum LocationOutcome { ok, serviceOff, denied, deniedForever, unavailable }

class LocationResult {
  const LocationResult(this.outcome, {this.point, this.accuracyMeters, this.mocked = false});
  final LocationOutcome outcome;
  final GeoPoint? point;
  final double? accuracyMeters;

  /// Android reports positions injected by "mock location" apps (Q8 fraud check).
  final bool mocked;

  bool get ok => outcome == LocationOutcome.ok && point != null;

  String describeProblem() => switch (outcome) {
        LocationOutcome.ok => '',
        LocationOutcome.serviceOff => 'Location is switched off. Turn it on in system settings and try again.',
        LocationOutcome.denied => 'Location permission was not given.',
        LocationOutcome.deniedForever =>
          'Location permission is blocked. Allow it for AquaAware in system settings.',
        LocationOutcome.unavailable => 'Location is not available on this device right now.',
      };
}

/// Asks for location only when a feature needs it, never in the background.
abstract final class LocationService {
  static Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationOutcome.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationOutcome.denied);
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationOutcome.deniedForever);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationResult(
        LocationOutcome.ok,
        point: GeoPoint(pos.latitude, pos.longitude),
        accuracyMeters: pos.accuracy,
        mocked: pos.isMocked,
      );
    } catch (_) {
      return const LocationResult(LocationOutcome.unavailable);
    }
  }
}
