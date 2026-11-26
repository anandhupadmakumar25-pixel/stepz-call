import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final bool success;
  final Position? position;
  final String? errorMessage;
  final bool isPermissionDenied;
  final bool isLocationServiceDisabled;

  LocationResult({
    required this.success,
    this.position,
    this.errorMessage,
    this.isPermissionDenied = false,
    this.isLocationServiceDisabled = false,
  });
}

class LocationService {
  /// Request GPS permissions and retrieve the device's live GPS coordinates.
  /// No manual typing or coordinate entry required.
  static Future<LocationResult> getCurrentLocation() async {
    try {
      // 1. Verify if device location services are enabled
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        return LocationResult(
          success: false,
          errorMessage: 'Location services are disabled on your device. Please turn on GPS.',
          isLocationServiceDisabled: true,
        );
      }

      // 2. Check and request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult(
            success: false,
            errorMessage: 'Location permission was denied. Location is required for automatic attendance punch.',
            isPermissionDenied: true,
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          success: false,
          errorMessage: 'Location permissions are permanently denied. Please enable them in app settings.',
          isPermissionDenied: true,
        );
      }

      // 3. Attempt Best-for-Navigation GPS acquisition (with 8s timeout)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (e) {
        debugPrint('Best-for-navigation GPS timed out: $e. Falling back to high accuracy...');
      }

      // 4. Fallback to High Accuracy if bestForNavigation timed out
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 6),
            ),
          );
        } catch (e) {
          debugPrint('High accuracy GPS timed out: $e. Falling back to medium accuracy...');
        }
      }

      // 5. Fallback to Medium Accuracy (Cell/Wi-Fi) if high accuracy timed out
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (e) {
          debugPrint('Medium accuracy location attempt failed: $e. Checking last known position...');
        }
      }

      // 6. Final Fallback: Last known location
      position ??= await Geolocator.getLastKnownPosition();

      if (position == null) {
        return LocationResult(
          success: false,
          errorMessage: 'Unable to acquire GPS signal. Please check your network/satellite reception.',
        );
      }

      return LocationResult(success: true, position: position);
    } catch (e) {
      return LocationResult(
        success: false,
        errorMessage: 'GPS detection error: ${e.toString()}',
      );
    }
  }

  /// Samples up to [samples] quick GPS fixes and returns the reading with the
  /// tightest horizontal accuracy (lowest meters), stopping early if <= 12m.
  static Future<LocationResult> getAccurateLocation({int samples = 3}) async {
    LocationResult? bestResult;
    for (int i = 0; i < samples; i++) {
      final res = await getCurrentLocation();
      if (!res.success || res.position == null) {
        if (bestResult == null && i == samples - 1) return res;
        continue;
      }
      if (bestResult == null ||
          res.position!.accuracy < bestResult.position!.accuracy) {
        bestResult = res;
      }
      if (bestResult.position!.accuracy <= 12.0) {
        break;
      }
    }
    return bestResult ?? await getCurrentLocation();
  }

  /// Calculates geodesic distance in meters between two coordinates.
  static double getDistanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
