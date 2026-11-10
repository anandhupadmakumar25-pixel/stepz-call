import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../routes/app_routes.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/widgets/stepz_punch_widget.dart';
import '../../core/services/location_service.dart';
import '../../models/attendance_model.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _filterBranch = 'ALL';
  String _filterDepartment = 'ALL';
  String _filterStatus = 'ALL';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  void _refreshAll() {
    final attP = context.read<AttendanceProvider>();
    attP.fetchTodayStatus();
    context.read<LeadProvider>().fetchBranches();
    context.read<DepartmentProvider>().fetchDepartments();

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    attP.fetchAdminRecords(
      date: dateStr,
      branchId: _filterBranch,
      departmentId: _filterDepartment,
      status: _filterStatus,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showFieldVisitDialog() {
    final placeCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return StatefulBuilder(
          builder: (context, setDlgState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: GlassCard(
                blur: 24,
                opacity: 0.96,
                borderRadius: BorderRadius.circular(20),
                borderColor: AppColors.glassBorderHighlight,
                padding: EdgeInsets.all(isMobile ? 18 : 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppColors.cyanGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Log Field / Client Visit',
                              style: GoogleFonts.inter(fontSize: isMobile ? 15 : 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                            ),
                          ),
                          DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Automatic GPS Capture Notice
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.neonCyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.gps_fixed_rounded, color: AppColors.neonCyan, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Live GPS satellite coordinates will be recorded automatically.',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      GlassTextField(
                        label: 'Place / Client Name *',
                        hintText: 'e.g. Tata Motors Showroom or Client HQ',
                        controller: placeCtrl,
                      ),
                      const SizedBox(height: 12),
                      GlassTextField(
                        label: 'Address / Location (Optional)',
                        hintText: 'e.g. Indiranagar 100ft Road',
                        controller: addressCtrl,
                      ),
                      const SizedBox(height: 12),
                      GlassTextField(
                        label: 'Meeting Remarks / Outcome',
                        hintText: 'e.g. Demonstrated CRM app, proposal requested',
                        controller: remarksCtrl,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.only(top: 14),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0x33D4AF37), width: 1.0)),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            GlassSecondaryButton(text: 'Cancel', onPressed: () => Navigator.pop(ctx)),
                            GradientPrimaryButton(
                              text: 'Save Field Visit',
                              icon: Icons.check_rounded,
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (placeCtrl.text.trim().isEmpty) return;
                                      setDlgState(() => isSubmitting = true);
                                      final attP = context.read<AttendanceProvider>();
                                      final nav = Navigator.of(ctx);
                                      final scaf = ScaffoldMessenger.of(context);

                                      // Auto-detect live GPS location
                                      final posResult = await LocationService.getCurrentLocation();
                                      final lat = posResult.position?.latitude;
                                      final lng = posResult.position?.longitude;

                                      final ok = await attP.recordFieldVisit(
                                        placeName: placeCtrl.text.trim(),
                                        address: addressCtrl.text.trim(),
                                        latitude: lat,
                                        longitude: lng,
                                        remarks: remarksCtrl.text.trim(),
                                      );
                                      setDlgState(() => isSubmitting = false);
                                      if (ok) {
                                        nav.pop();
                                        scaf.showSnackBar(
                                          const SnackBar(content: Text('Field visit logged successfully!'), backgroundColor: AppColors.success),
                                        );
                                        attP.fetchTodayStatus();
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRouteModal(AttendanceModel rec) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.cyanGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.route_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${rec.userName} • Field Route Timeline',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Date: ${rec.date} • ${rec.fieldVisits.length} Stops Logged',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              Expanded(
                child: rec.fieldVisits.isEmpty
                    ? Center(
                        child: Text('No field visits logged for this date.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                      )
                    : ListView.builder(
                        itemCount: rec.fieldVisits.length,
                        itemBuilder: (context, i) {
                          final v = rec.fieldVisits[i];
                          final timeStr = v.visitedAt != null
                              ? DateFormat('hh:mm a').format(v.visitedAt!.toLocal())
                              : '--:--';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: AppColors.neonCyan.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.neonCyan),
                                      ),
                                      child: Center(
                                        child: Text('${i + 1}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.neonCyan)),
                                      ),
                                    ),
                                    if (i != rec.fieldVisits.length - 1)
                                      Container(width: 2, height: 40, color: const Color(0xFFE2E8F0)),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(v.placeName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                            Text(timeStr, style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.neonCyan)),
                                          ],
                                        ),
                                        if (v.address.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.pin_drop_rounded, size: 12, color: Color(0xFF64748B)),
                                              const SizedBox(width: 4),
                                              Expanded(child: Text(v.address, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)))),
                                            ],
                                          ),
                                        ],
                                        if (v.latitude != null && v.longitude != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text('GPS: ${v.latitude!.toStringAsFixed(4)}, ${v.longitude!.toStringAsFixed(4)}', style: GoogleFonts.robotoMono(fontSize: 10, color: const Color(0xFF94A3B8))),
                                          ),
                                        if (v.remarks.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text('Remarks: ${v.remarks}', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic, color: const Color(0xFF334155))),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider>().currentUser;
    final isMobile = ResponsiveLayout.isMobile(context);
    final canViewTeamBoard = authUser?.isSuperAdmin == true ||
        authUser?.isCompanyAdmin == true ||
        authUser?.isManager == true ||
        (authUser?.hasPermission('attendance.view_team_board') == true);

    final nowFormatted = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 12 : 24,
            isMobile ? 6 : 16,
            isMobile ? 12 : 24,
            isMobile ? 10 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppBackButton(fallbackRoute: AppRoutes.dashboard),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stepz Attendance & Field Log',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nowFormatted,
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.neonCyan),
                    tooltip: 'Refresh Status',
                    onPressed: _refreshAll,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (canViewTeamBoard) ...[
                // Tab Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  padding: const EdgeInsets.all(5),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonViolet.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                    tabs: const [
                      Tab(text: 'MY PUNCH & FIELD VISITS'),
                      Tab(text: 'LIVE TEAM ATTENDANCE & ROUTES'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Content Area
              Expanded(
                child: canViewTeamBoard
                    ? TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMyPunchView(authUser, isMobile),
                          _buildTeamBoardView(isMobile),
                        ],
                      )
                    : _buildMyPunchView(authUser, isMobile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyPunchView(dynamic user, bool isMobile) {
    final attP = context.watch<AttendanceProvider>();
    final today = attP.todayAttendance;
    final isCheckedIn = attP.isCheckedIn;
    final isCheckedOut = attP.isCheckedOut;
    final isFieldStaff = today?.isFieldStaffMode ?? false;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile & Tracking Mode Card
          GlassCard(
            blur: 18,
            opacity: 0.12,
            borderRadius: BorderRadius.circular(16),
            borderColor: AppColors.glassBorder,
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonViolet.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.fingerprint_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Staff Member',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          '${user?.role ?? 'EMPLOYEE'} • ${today?.departmentName.isNotEmpty == true ? today!.departmentName : 'General'}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isFieldStaff ? AppColors.neonCyan : AppColors.neonViolet).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: (isFieldStaff ? AppColors.neonCyan : AppColors.neonViolet).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isFieldStaff ? Icons.directions_car_rounded : Icons.business_rounded, size: 14, color: isFieldStaff ? AppColors.neonCyan : AppColors.neonViolet),
                      const SizedBox(width: 6),
                      Text(
                        isFieldStaff ? 'Field Staff Tracking Mode' : 'Office Geo-fence Mode (100m)',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isFieldStaff ? AppColors.neonCyan : AppColors.neonViolet),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Punch Action Card powered by automatic GPS
          StepzPunchWidget(onAttendanceChanged: _refreshAll),
          const SizedBox(height: 16),

          if (isFieldStaff && isCheckedIn && !isCheckedOut && (user?.hasPermission('attendance.field_visit') ?? true)) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: GradientPrimaryButton(
                text: 'Log Field / Client Visit',
                icon: Icons.add_location_alt_rounded,
                gradient: AppColors.cyanGradient,
                onPressed: _showFieldVisitDialog,
              ),
            ),
            const SizedBox(height: 18),
          ],
          const SizedBox(height: 20),

          // Field Visits Log Section (For Field Staff)
          if (isFieldStaff) ...[
            Text('Today’s Field Visits Log', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
            const SizedBox(height: 10),
            attP.todayVisits.isEmpty
                ? GlassCard(
                    blur: 16,
                    opacity: 0.12,
                    borderColor: AppColors.glassBorder,
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('No field client visits logged yet today.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: attP.todayVisits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final v = attP.todayVisits[i];
                      final timeStr = v.visitedAt != null ? DateFormat('hh:mm a').format(v.visitedAt!.toLocal()) : '';
                      return GlassCard(
                        blur: 16,
                        opacity: 0.12,
                        borderRadius: BorderRadius.circular(14),
                        borderColor: AppColors.glassBorder,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.neonCyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.pin_drop_rounded, color: AppColors.neonCyan, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(v.placeName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                      Text(timeStr, style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.neonCyan)),
                                    ],
                                  ),
                                  if (v.address.isNotEmpty)
                                    Text(v.address, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                  if (v.remarks.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text('Note: ${v.remarks}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF334155))),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamBoardView(bool isMobile) {
    final attP = context.watch<AttendanceProvider>();
    final leadP = context.watch<LeadProvider>();
    final deptP = context.watch<DepartmentProvider>();
    final summary = attP.adminSummary;
    final records = attP.adminRecords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // KPI Metrics Row
        if (isMobile)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildKPITile('Total Staff', '${summary['total_employees'] ?? 0}', AppColors.neonViolet),
              _buildKPITile('Present', '${summary['present_count'] ?? 0}', const Color(0xFF10B981)),
              _buildKPITile('Late', '${summary['late_count'] ?? 0}', const Color(0xFFF59E0B)),
              _buildKPITile('Out of Fence', '${summary['out_of_fence_count'] ?? 0}', const Color(0xFFEF4444)),
            ],
          )
        else
          Row(
            children: [
              Expanded(child: _buildKPITile('Total Staff', '${summary['total_employees'] ?? 0}', AppColors.neonViolet)),
              const SizedBox(width: 10),
              Expanded(child: _buildKPITile('Present', '${summary['present_count'] ?? 0}', const Color(0xFF10B981))),
              const SizedBox(width: 10),
              Expanded(child: _buildKPITile('Late', '${summary['late_count'] ?? 0}', const Color(0xFFF59E0B))),
              const SizedBox(width: 10),
              Expanded(child: _buildKPITile('Out of Fence', '${summary['out_of_fence_count'] ?? 0}', const Color(0xFFEF4444))),
              const SizedBox(width: 10),
              Expanded(child: _buildKPITile('Absent', '${summary['absent_count'] ?? 0}', const Color(0xFF94A3B8))),
            ],
          ),
        const SizedBox(height: 14),

        // Filter Bar
        GlassCard(
          blur: 16,
          opacity: 0.12,
          borderRadius: BorderRadius.circular(14),
          borderColor: AppColors.glassBorder,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Date picker button
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2025),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _refreshAll();
                  }
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.neonCyan),
                label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate), style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
              ),

              // Branch Filter
              DropdownButton<String>(
                value: _filterBranch,
                underline: const SizedBox(),
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('All Branches')),
                  ...leadP.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                ],
                onChanged: (v) {
                  setState(() => _filterBranch = v ?? 'ALL');
                  _refreshAll();
                },
              ),

              // Department Filter
              DropdownButton<String>(
                value: _filterDepartment,
                underline: const SizedBox(),
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('All Departments')),
                  ...deptP.departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                ],
                onChanged: (v) {
                  setState(() => _filterDepartment = v ?? 'ALL');
                  _refreshAll();
                },
              ),

              // Status Filter
              DropdownButton<String>(
                value: _filterStatus,
                underline: const SizedBox(),
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'PRESENT', child: Text('Present')),
                  DropdownMenuItem(value: 'LATE', child: Text('Late')),
                  DropdownMenuItem(value: 'OUT_OF_FENCE', child: Text('Out of Fence')),
                  DropdownMenuItem(value: 'ABSENT', child: Text('Absent')),
                ],
                onChanged: (v) {
                  setState(() => _filterStatus = v ?? 'ALL');
                  _refreshAll();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Team Records List
        Expanded(
          child: attP.isLoading
              ? const Center(child: CircularProgressIndicator())
              : records.isEmpty
                  ? Center(
                      child: GlassCard(
                        blur: 16,
                        opacity: 0.12,
                        borderColor: AppColors.glassBorder,
                        padding: const EdgeInsets.all(32),
                        child: Text('No attendance records found for selected filter.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
                      ),
                    )
                  : ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final rec = records[i];
                        final inTime = rec.checkInTime != null ? DateFormat('hh:mm a').format(rec.checkInTime!.toLocal()) : '--';
                        final outTime = rec.checkOutTime != null ? DateFormat('hh:mm a').format(rec.checkOutTime!.toLocal()) : '--';
                        final isFieldStaff = rec.isFieldStaffMode;

                        Color statusColor = const Color(0xFF10B981);
                        if (rec.status == 'LATE') statusColor = const Color(0xFFF59E0B);
                        if (rec.status == 'OUT_OF_FENCE') statusColor = const Color(0xFFEF4444);
                        if (rec.status == 'ABSENT') statusColor = const Color(0xFF94A3B8);

                        return GlassCard(
                          blur: 18,
                          opacity: 0.12,
                          borderRadius: BorderRadius.circular(16),
                          borderColor: AppColors.glassBorder,
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isFieldStaff ? Icons.directions_car_rounded : Icons.person_rounded,
                                        color: statusColor,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(rec.userName, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                      Text('${rec.departmentName.isNotEmpty ? rec.departmentName : 'General'} • ${rec.matchedBranchName.isNotEmpty ? rec.matchedBranchName : 'HQ'}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
                                    ],
                                  ),
                                ],
                              ),
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('In: $inTime', style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFF334155))),
                                  Text('Out: $outTime', style: GoogleFonts.robotoMono(fontSize: 11, color: const Color(0xFF334155))),
                                  if (rec.workingHours > 0)
                                    Text('${rec.workingHours.toStringAsFixed(1)}h', style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                                  AnimatedStatusBadge(label: rec.status, statusColor: statusColor),
                                  if (!isFieldStaff && rec.checkInTime != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (rec.checkInInGeofence ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: (rec.checkInInGeofence ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            rec.checkInInGeofence ? Icons.check_circle_rounded : Icons.location_off_rounded,
                                            size: 11,
                                            color: rec.checkInInGeofence ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            rec.checkInInGeofence
                                                ? 'Inside Office'
                                                : (rec.checkInDistanceMeters != null
                                                    ? 'Outside (${rec.checkInDistanceMeters!.toStringAsFixed(0)}m)'
                                                    : 'Outside (?)'),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: rec.checkInInGeofence ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (rec.fieldVisits.isNotEmpty)
                                    TextButton.icon(
                                      onPressed: () => _showRouteModal(rec),
                                      icon: const Icon(Icons.route_rounded, size: 14),
                                      label: Text('Route (${rec.fieldVisits.length})', style: GoogleFonts.inter(fontSize: 11)),
                                      style: TextButton.styleFrom(foregroundColor: AppColors.neonCyan),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildKPITile(String title, String count, Color color) {
    return GlassCard(
      blur: 16,
      opacity: 0.12,
      borderRadius: BorderRadius.circular(14),
      borderColor: AppColors.glassBorder,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count, style: GoogleFonts.robotoMono(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(title, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
