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

    // Strict geofence validation for office employees (cannot check in outside radius)
    if (!isFieldStaff && !_isInsideGeofence && _closestBranch != null) {
      final distStr = '${_distanceToClosestBranchMeters?.toStringAsFixed(0) ?? '?'} m';
      final allowedRadiusStr = '${_closestBranch!.radiusMeters > 0 ? _closestBranch!.radiusMeters : 100} m';

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.location_off_rounded, color: Color(0xFFDC2626), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Outside Location Radius',
                  style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 16),
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
                style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Check-in is strictly allowed only within the $allowedRadiusStr office perimeter. Please move inside the allowed radius and refresh GPS.',
                style: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 12.5, height: 1.45),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonCyan,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.my_location_rounded, size: 16),
              label: const Text('Refresh GPS'),
              onPressed: () async {
                Navigator.pop(ctx);
                await _detectLocation();
              },
            ),
          ],
        ),
      );
      return;
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

    final attP = context.read<AttendanceProvider>();
    final now = DateTime.now();
    bool isEarlyCheckout = false;
    final endStr = attP.shiftEndTime ?? '18:00:00';
    final parts = endStr.split(':');
    if (parts.length >= 2) {
      final endH = int.tryParse(parts[0]) ?? 18;
      final endM = int.tryParse(parts[1]) ?? 0;
      final shiftEndToday = DateTime(now.year, now.month, now.day, endH, endM);
      isEarlyCheckout = now.isBefore(shiftEndToday);
    }

    final reasonCtrl = TextEditingController();
    String? dialogError;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: AppColors.neonCoral, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEarlyCheckout ? 'Early Check Out — Reason Required' : 'Confirm Check Out?',
                  style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEarlyCheckout
                    ? 'You are checking out before office shift end time ($endStr). Please enter your reason (e.g. outside client visit, break, personal work).'
                    : 'Are you sure you want to check out? You can check in again later today if you return.',
                style: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 13, height: 1.4),
              ),
              if (isEarlyCheckout) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Checkout Reason *',
                    hintText: 'Why are you checking out early?',
                    errorText: dialogError,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonCoral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (isEarlyCheckout && reasonCtrl.text.trim().isEmpty) {
                  setDlgState(() => dialogError = 'Please enter a reason');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Confirm Check Out', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || !mounted) return;

    final ok = await attP.checkOut(
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
      address: _closestBranch != null ? '${_closestBranch!.name} Perimeter' : 'Live GPS Check-out',
      notes: reasonCtrl.text.trim(),
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checked out successfully!'),
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
    return;
  }

  @override
  Widget build(BuildContext context) {
    final attP = context.watch<AttendanceProvider>();
    final today = attP.todayAttendance;
    final isCheckedIn = attP.isCheckedIn;
    final isCheckedOut = attP.isCheckedOut;
    final isFieldStaff = today?.isFieldStaffMode ?? false;

    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);

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
              Expanded(
                child: Row(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stepz Attendance',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isFieldStaff ? 'Field Staff Track Mode' : 'Office Geofence (100m Perimeter)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: GoogleFonts.robotoMono(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    DateFormat('EEE, MMM d').format(_currentTime),
                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
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
                          text: 'Check In',
                          icon: Icons.fingerprint_rounded,
                          height: 40,
                          gradient: _isInsideGeofence || isFieldStaff
                              ? AppColors.primaryGradient
                              : const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF64748B)]),
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
                        text: 'Check Out',
                        icon: Icons.logout_rounded,
                        height: 38,
                        onPressed: _handlePunchOut,
                      ),
              ],
            ),
          ] else ...[
            // Status: Checked Out -> Show Today's Logged Hours + Allow Re-Check-In
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Checked Out (${attP.sessionsTodayCount} session${attP.sessionsTodayCount == 1 ? '' : 's'} today)',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Total Logged Today: ${attP.totalHoursToday.toStringAsFixed(2)} hrs · Last: ${today?.checkOutTime != null ? DateFormat('hh:mm a').format(today!.checkOutTime!.toLocal()) : '--'}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  attP.isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : GradientPrimaryButton(
                          text: 'Check In',
                          icon: Icons.fingerprint_rounded,
                          height: 36,
                          gradient: _isInsideGeofence || isFieldStaff
                              ? AppColors.primaryGradient
                              : const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF64748B)]),
                          onPressed: () => _handlePunchIn(isFieldStaff),
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
