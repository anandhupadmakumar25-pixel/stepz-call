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

      // 3. Attempt High Accuracy GPS acquisition (with 6s timeout)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (e) {
        debugPrint('High accuracy GPS timed out or failed: $e. Falling back to medium accuracy...');
      }

      // 4. Fallback to Medium Accuracy (Cell/Wi-Fi) if high accuracy timed out
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

      // 5. Final Fallback: Last known location
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
