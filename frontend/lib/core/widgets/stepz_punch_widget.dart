import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import 'glass/glass_card.dart';
import 'glass/gradient_button.dart';
import 'glass/animated_status_badge.dart';
import '../services/location_service.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/lead_provider.dart';
import '../../models/lead_model.dart';

class StepzPunchWidget extends StatefulWidget {
  final bool compact;
  final VoidCallback? onAttendanceChanged;

  const StepzPunchWidget({
    super.key,
    this.compact = false,
    this.onAttendanceChanged,
  });

  @override
  State<StepzPunchWidget> createState() => _StepzPunchWidgetState();
}

class _StepzPunchWidgetState extends State<StepzPunchWidget> {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  Position? _currentPosition;
  bool _isDetectingGps = false;
  String? _gpsError;

  BranchModel? _closestBranch;
  double? _distanceToClosestBranchMeters;
  bool _isInsideGeofence = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAttendanceAndDetectGps();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAttendanceAndDetectGps() async {
    final attP = context.read<AttendanceProvider>();
    final leadP = context.read<LeadProvider>();
    await attP.fetchTodayStatus();
    await leadP.fetchBranches();
    await _detectLocation();
  }

  Future<void> _detectLocation() async {
    if (!mounted) return;
    setState(() {
      _isDetectingGps = true;
      _gpsError = null;
    });

    final result = await LocationService.getCurrentLocation();
    if (!mounted) return;

    if (result.success && result.position != null) {
      final pos = result.position!;
      final branches = context.read<LeadProvider>().branches;

      BranchModel? closest;
      double? minDistance;
      bool inFence = false;

      if (branches.isNotEmpty) {
        for (final b in branches) {
          if (b.latitude != null && b.longitude != null) {
            final dist = LocationService.getDistanceBetween(
              pos.latitude,
              pos.longitude,
              b.latitude!,
              b.longitude!,
            );
            if (minDistance == null || dist < minDistance) {
              minDistance = dist;
              closest = b;
            }
          }
        }
        if (closest != null && minDistance != null) {
          final radius = closest.radiusMeters > 0 ? closest.radiusMeters : 100;
          inFence = minDistance <= radius;
        }
      }

      setState(() {
        _currentPosition = pos;
        _closestBranch = closest;
        _distanceToClosestBranchMeters = minDistance;
        _isInsideGeofence = inFence;
        _isDetectingGps = false;
      });
    } else {
      setState(() {
        _gpsError = result.errorMessage ?? 'Unable to detect device location.';
        _isDetectingGps = false;
      });
    }
  }

  Future<void> _handlePunchIn(bool isFieldStaff) async {
    if (_currentPosition == null) {
      await _detectLocation();
    }
    if (!mounted) return;

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_gpsError ?? 'Live GPS location is required to punch in. Please enable GPS.'),
          backgroundColor: AppColors.neonCoral,
        ),
      );
      return;
    }

    // Geofence validation for office employees
    if (!isFieldStaff && !_isInsideGeofence && _closestBranch != null) {
      final distStr = '${_distanceToClosestBranchMeters?.toStringAsFixed(0) ?? '?'} m';
      final allowedRadiusStr = '${_closestBranch!.radiusMeters} m';

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Outside Office Geofence',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are currently $distStr away from "${_closestBranch!.name}".',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Company policy requires check-in within the $allowedRadiusStr office perimeter.\n\n'
                'If you punch in now, your record will be marked as "OUT_OF_FENCE" with your exact GPS coordinates visible to your supervisor.',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Punch Anyway (Out of Fence)',
                style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
      );

      if (proceed != true || !mounted) return;
    }

    if (!mounted) return;

    final attP = context.read<AttendanceProvider>();
    final addressLabel = _closestBranch != null
        ? '${_closestBranch!.name} Perimeter'
        : 'Live GPS Check-in';

    final ok = await attP.checkIn(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      address: addressLabel,
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Punch-in successfully recorded! Shift started.'),
          backgroundColor: AppColors.success,
        ),
      );
      await attP.fetchTodayStatus();
      widget.onAttendanceChanged?.call();
    } else if (attP.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(attP.errorMessage!), backgroundColor: AppColors.neonCoral),
      );
    }
  }

  Future<void> _handlePunchOut() async {
    if (_currentPosition == null) {
      await _detectLocation();
    }
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('End Shift & Punch Out?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Your final working hours will be logged based on your live GPS timestamp.',
          style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonCoral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Punch Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final attP = context.read<AttendanceProvider>();
    final ok = await attP.checkOut(
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
      address: _closestBranch != null ? '${_closestBranch!.name} Perimeter' : 'Live GPS Punch-out',
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Punch-out recorded! Shift closed for today.'),
          backgroundColor: AppColors.success,
        ),
      );
      await attP.fetchTodayStatus();
      widget.onAttendanceChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final attP = context.watch<AttendanceProvider>();
    final today = attP.todayAttendance;
    final isCheckedIn = attP.isCheckedIn;
    final isCheckedOut = attP.isCheckedOut;
    final isFieldStaff = today?.isFieldStaffMode ?? false;

    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(_currentTime);

    return GlassCard(
      blur: 20,
      opacity: 0.16,
      borderRadius: BorderRadius.circular(20),
      borderColor: isCheckedIn && !isCheckedOut
          ? const Color(0xFF10B981).withValues(alpha: 0.4)
          : AppColors.glassBorderHighlight,
      padding: EdgeInsets.all(widget.compact ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar: Stepz Attendance Brand & Real-time Clock
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: isCheckedIn && !isCheckedOut
                          ? AppColors.emeraldGradient
                          : AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isCheckedIn && !isCheckedOut ? const Color(0xFF10B981) : AppColors.neonViolet)
                              .withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isCheckedIn && !isCheckedOut
                          ? Icons.fingerprint_rounded
                          : Icons.how_to_reg_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stepz Attendance',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        isFieldStaff ? 'Field Staff Track Mode' : 'Office Geofence (100m Perimeter)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: GoogleFonts.robotoMono(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live GPS Detection & Geofence Proximity Status Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _isDetectingGps
                  ? Colors.white.withValues(alpha: 0.05)
                  : isFieldStaff
                      ? AppColors.neonCyan.withValues(alpha: 0.08)
                      : _isInsideGeofence
                          ? const Color(0xFF10B981).withValues(alpha: 0.08)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isDetectingGps
                    ? AppColors.glassBorder
                    : isFieldStaff
                        ? AppColors.neonCyan.withValues(alpha: 0.3)
                        : _isInsideGeofence
                            ? const Color(0xFF10B981).withValues(alpha: 0.35)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                if (_isDetectingGps) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonCyan),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Detecting live device GPS coordinates...',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ),
                ] else if (_gpsError != null) ...[
                  const Icon(Icons.location_off_rounded, color: AppColors.neonCoral, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _gpsError!,
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.neonCoral, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.neonCyan),
                    tooltip: 'Retry GPS Detection',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _detectLocation,
                  ),
                ] else if (isFieldStaff) ...[
                  const Icon(Icons.directions_car_rounded, color: AppColors.neonCyan, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dynamic GPS Field Staff Mode Active',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.neonCyan),
                        ),
                        if (_currentPosition != null)
                          Text(
                            'Live GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)} (Accuracy: ±${_currentPosition!.accuracy.toStringAsFixed(0)}m)',
                            style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                ] else ...[
                  Icon(
                    _isInsideGeofence ? Icons.verified_rounded : Icons.warning_amber_rounded,
                    color: _isInsideGeofence ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isInsideGeofence
                              ? 'Inside Office Geofence'
                              : 'Outside Assigned Office Geofence',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isInsideGeofence ? const Color(0xFF10B981) : const Color(0xFFD97706),
                          ),
                        ),
                        Text(
                          _closestBranch != null && _distanceToClosestBranchMeters != null
                              ? '${_distanceToClosestBranchMeters!.toStringAsFixed(0)}m from "${_closestBranch!.name}" (Max ${_closestBranch!.radiusMeters}m radius)'
                              : (_currentPosition != null
                                  ? 'GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                                  : 'No office coordinates configured yet'),
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.my_location_rounded, size: 16, color: AppColors.neonCyan),
                    tooltip: 'Recalculate Proximity',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _detectLocation,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Shift Status Details & Punch Button Action
          if (!isCheckedIn) ...[
            // Status: Not Checked In -> Show PUNCH IN
            Row(
              children: [
                Expanded(
                  child: attP.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GradientPrimaryButton(
                          text: 'PUNCH IN',
                          icon: Icons.fingerprint_rounded,
                          gradient: _isInsideGeofence || isFieldStaff
                              ? AppColors.primaryGradient
                              : const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                          onPressed: () => _handlePunchIn(isFieldStaff),
                        ),
                ),
              ],
            ),
          ] else if (isCheckedIn && !isCheckedOut) ...[
            // Status: Checked In -> Show Status + PUNCH OUT
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Punched In at ${today?.checkInTime != null ? DateFormat('hh:mm a').format(today!.checkInTime!.toLocal()) : '--:--'}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedStatusBadge(
                          label: today?.status ?? 'PRESENT',
                          statusColor: today?.status == 'LATE'
                              ? const Color(0xFFF59E0B)
                              : today?.status == 'OUT_OF_FENCE'
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981),
                        ),
                        if (today?.matchedBranchName.isNotEmpty == true) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${today!.matchedBranchName}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                attP.isLoading
                    ? const CircularProgressIndicator()
                    : GlassSecondaryButton(
                        text: 'PUNCH OUT',
                        icon: Icons.logout_rounded,
                        onPressed: _handlePunchOut,
                      ),
              ],
            ),
          ] else ...[
            // Status: Shift Completed
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift Completed for Today',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Total Logged: ${today?.workingHours.toStringAsFixed(1) ?? '0.0'} hrs (${today?.checkInTime != null ? DateFormat('hh:mm a').format(today!.checkInTime!.toLocal()) : '--'} to ${today?.checkOutTime != null ? DateFormat('hh:mm a').format(today!.checkOutTime!.toLocal()) : '--'})',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
