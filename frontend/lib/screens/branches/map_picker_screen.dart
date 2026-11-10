import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/location_service.dart';

class MapPickerResult {
  final double latitude;
  final double longitude;

  const MapPickerResult({
    required this.latitude,
    required this.longitude,
  });
}

class MapPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final int radiusMeters;
  final String title;

  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.radiusMeters = 100,
    this.title = 'Pick Office / Branch Geofence',
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  late ll.LatLng _currentPosition;
  bool _isMoving = false;
  bool _isLocating = false;
  late int _radiusMeters;

  @override
  void initState() {
    super.initState();
    _radiusMeters = widget.radiusMeters;
    final double lat = widget.initialLatitude ?? 12.9716; // Default Bangalore/HQ
    final double lng = widget.initialLongitude ?? 77.5946;
    _currentPosition = ll.LatLng(lat, lng);

    if (widget.initialLatitude == null || widget.initialLongitude == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _moveToCurrentLocation();
      });
    }
  }

  Future<void> _moveToCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final locResult = await LocationService.getCurrentLocation();
      if (locResult.success && locResult.position != null) {
        final target = ll.LatLng(locResult.position!.latitude, locResult.position!.longitude);
        setState(() {
          _currentPosition = target;
        });
        _mapController.move(target, 17.0);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(locResult.errorMessage ?? 'Could not detect device GPS location.'),
              backgroundColor: AppColors.neonCoral,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: AppColors.neonCoral,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _zoomIn() {
    final zoom = _mapController.camera.zoom;
    _mapController.move(_currentPosition, zoom + 1);
  }

  void _zoomOut() {
    final zoom = _mapController.camera.zoom;
    _mapController.move(_currentPosition, zoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Flutter Map (Native OSM / CartoDB raster tiles) ─────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition,
              initialZoom: 16.5,
              minZoom: 4,
              maxZoom: 19,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _currentPosition = camera.center;
                  });
                }
              },
              onPointerDown: (_, __) => setState(() => _isMoving = true),
              onPointerUp: (_, __) => setState(() => _isMoving = false),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.stepz.telecaller_crm',
                maxZoom: 19,
              ),
              // Geofence Circle overlay showing exact allowed radius
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _currentPosition,
                    radius: _radiusMeters.toDouble(),
                    useRadiusInMeter: true,
                    color: AppColors.neonCyan.withValues(alpha: 0.18),
                    borderColor: AppColors.neonCyan,
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
            ],
          ),

          // ── Center Pin Overlay with Animated Bounce ──────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 38),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                transform: Matrix4.translationValues(0, _isMoving ? -14 : 0, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonCyan.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        'Office / Gate Spot (${_radiusMeters}m Fence)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Icon(
                      Icons.location_on_rounded,
                      size: 46,
                      color: AppColors.neonCyan,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Center target dot
          Center(
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),

          // ── Map Floating Action Controls ───────────────────────────────────
          Positioned(
            right: 18,
            bottom: 235,
            child: Column(
              children: [
                _MapControlButton(
                  tooltip: 'Center to My Location',
                  onPressed: _isLocating ? null : _moveToCurrentLocation,
                  child: _isLocating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.my_location_rounded, color: AppColors.neonCyan, size: 22),
                ),
                const SizedBox(height: 10),
                _MapControlButton(
                  tooltip: 'Zoom In',
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 10),
                _MapControlButton(
                  tooltip: 'Zoom Out',
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove_rounded, color: Colors.white, size: 22),
                ),
              ],
            ),
          ),

          // ── Bottom Confirmation Sheet ─────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.90),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.2,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.neonCyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.pin_drop_rounded,
                                color: AppColors.neonCyan,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected Office Coordinates',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Cyan circle shows the active ${_radiusMeters}m geofence boundary',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _CoordinateBox(
                                label: 'LATITUDE',
                                value: _currentPosition.latitude.toStringAsFixed(7),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _CoordinateBox(
                                label: 'LONGITUDE',
                                value: _currentPosition.longitude.toStringAsFixed(7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.neonCyan.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(
                                context,
                                MapPickerResult(
                                  latitude: _currentPosition.latitude,
                                  longitude: _currentPosition.longitude,
                                ),
                              );
                            },
                            child: Text(
                              'Confirm Location (${_radiusMeters}m Fence)',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? tooltip;

  const _MapControlButton({
    required this.onPressed,
    required this.child,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: child,
      ),
    );
  }
}

class _CoordinateBox extends StatelessWidget {
  final String label;
  final String value;

  const _CoordinateBox({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.robotoMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.robotoMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
