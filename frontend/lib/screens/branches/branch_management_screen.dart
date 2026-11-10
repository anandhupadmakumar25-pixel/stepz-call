import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass/glass_card.dart';
import '../../core/widgets/glass/gradient_button.dart';
import '../../core/widgets/glass/glass_text_field.dart';
import '../../core/widgets/glass/animated_status_badge.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../routes/app_routes.dart';
import '../../providers/lead_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/department_provider.dart';
import '../../providers/role_provider.dart';
import '../../models/lead_model.dart';
import '../../models/department_model.dart';
import '../../models/role_model.dart';
import '../../core/services/location_service.dart';
import 'map_picker_screen.dart';
import '../../providers/company_provider.dart';
import 'company_rules_tab.dart';

class BranchManagementScreen extends StatefulWidget {
  const BranchManagementScreen({super.key});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<LeadProvider>();
      p.fetchBranches();
      p.fetchCategories();
      context.read<EmployeeProvider>().fetchEmployees();
      context.read<DepartmentProvider>().fetchDepartments();
      context.read<RoleProvider>().fetchRoles();
      context.read<CompanyProvider>().fetchPayrollPolicy();
      context.read<CompanyProvider>().fetchCompanyRules();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation(
    TextEditingController latCtrl,
    TextEditingController lngCtrl,
    void Function(void Function()) setDlgState,
    BuildContext dialogCtx,
  ) async {
    final res = await LocationService.getCurrentLocation();
    if (res.success && res.position != null) {
      setDlgState(() {
        latCtrl.text = res.position!.latitude.toStringAsFixed(7);
        lngCtrl.text = res.position!.longitude.toStringAsFixed(7);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Current GPS coordinates detected and filled!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? 'Could not detect device GPS.'),
            backgroundColor: AppColors.neonCoral,
          ),
        );
      }
    }
  }

  Future<void> _openMapPicker(
    TextEditingController latCtrl,
    TextEditingController lngCtrl,
    TextEditingController radiusCtrl,
    void Function(void Function()) setDlgState,
    BuildContext dialogCtx,
  ) async {
    final initialLat = double.tryParse(latCtrl.text.trim());
    final initialLng = double.tryParse(lngCtrl.text.trim());
    final radius = int.tryParse(radiusCtrl.text.trim()) ?? 100;

    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLatitude: initialLat,
          initialLongitude: initialLng,
          radiusMeters: radius,
          title: 'Select Office / Branch Geofence',
        ),
      ),
    );

    if (result != null) {
      setDlgState(() {
        latCtrl.text = result.latitude.toStringAsFixed(7);
        lngCtrl.text = result.longitude.toStringAsFixed(7);
      });
    }
  }

  void _showAddBranchDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final radiusCtrl = TextEditingController(text: '100');
    bool geofenceEnabled = true;

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
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassCard(
                blur: 24,
                opacity: 0.96,
                borderRadius: BorderRadius.circular(20),
                borderColor: AppColors.glassBorderHighlight,
                padding: EdgeInsets.all(isMobile ? 18 : 26),
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
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Add Enterprise Branch & Geofence',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 15 : 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      GlassTextField(
                        label: 'Branch Name *',
                        hintText: 'e.g. Branch Alpha or Metro Campus',
                        controller: nameCtrl,
                      ),
                      const SizedBox(height: 14),
                      GlassTextField(
                        label: 'Branch Code',
                        hintText: 'e.g. BR-ALPHA or METRO-01',
                        controller: codeCtrl,
                      ),
                      const SizedBox(height: 14),
                      GlassTextField(
                        label: 'Address / Campus Location',
                        hintText: 'e.g. 5th Avenue, Suite 400',
                        controller: addressCtrl,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 18),

                      // Geofence configuration container
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.share_location_rounded, size: 18, color: AppColors.neonViolet),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Office Geofence Radius',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: geofenceEnabled,
                                  activeThumbColor: AppColors.neonCyan,
                                  onChanged: (val) => setDlgState(() => geofenceEnabled = val),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: GlassTextField(
                                    label: 'Latitude (GPS)',
                                    hintText: 'e.g. 12.9716000',
                                    controller: latCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GlassTextField(
                                    label: 'Longitude (GPS)',
                                    hintText: 'e.g. 77.5946000',
                                    controller: lngCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.neonCyan,
                                      side: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                                    ),
                                    onPressed: () => _fetchCurrentLocation(latCtrl, lngCtrl, setDlgState, ctx),
                                    icon: const Icon(Icons.my_location_rounded, size: 16),
                                    label: Text(
                                      'Take Current GPS',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.neonViolet.withValues(alpha: 0.25),
                                      foregroundColor: Colors.white,
                                      side: BorderSide(color: AppColors.neonViolet.withValues(alpha: 0.6)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _openMapPicker(latCtrl, lngCtrl, radiusCtrl, setDlgState, ctx),
                                    icon: const Icon(Icons.map_rounded, size: 16, color: AppColors.neonCyan),
                                    label: Text(
                                      'Pick on Map',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GlassTextField(
                              label: 'Fence Radius (meters)',
                              hintText: '100',
                              controller: radiusCtrl,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.only(top: 14),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0x33D4AF37), width: 1.0),
                          ),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            GlassSecondaryButton(
                              text: 'Cancel',
                              onPressed: () => Navigator.pop(ctx),
                            ),
                            GradientPrimaryButton(
                              text: 'Create Branch',
                              icon: Icons.check_rounded,
                              onPressed: () async {
                                if (nameCtrl.text.trim().isEmpty) return;
                                final p = context.read<LeadProvider>();
                                final nav = Navigator.of(ctx);
                                final scaf = ScaffoldMessenger.of(context);
                                final ok = await p.createBranch(
                                  name: nameCtrl.text.trim(),
                                  code: codeCtrl.text.trim(),
                                  address: addressCtrl.text.trim(),
                                  latitude: double.tryParse(latCtrl.text.trim()),
                                  longitude: double.tryParse(lngCtrl.text.trim()),
                                  radiusMeters: int.tryParse(radiusCtrl.text.trim()) ?? 100,
                                  geofenceEnabled: geofenceEnabled,
                                );
                                if (ok) {
                                  nav.pop();
                                  scaf.showSnackBar(
                                    const SnackBar(
                                      content: Text('Branch & Geofence created successfully!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
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

  void _showEditBranchDialog(BranchModel branch) {
    final nameCtrl = TextEditingController(text: branch.name);
    final codeCtrl = TextEditingController(text: branch.code);
    final addressCtrl = TextEditingController(text: branch.address);
    final latCtrl = TextEditingController(text: branch.latitude?.toString() ?? '');
    final lngCtrl = TextEditingController(text: branch.longitude?.toString() ?? '');
    final radiusCtrl = TextEditingController(text: branch.radiusMeters.toString());
    bool geofenceEnabled = branch.geofenceEnabled;

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
              constraints: const BoxConstraints(maxWidth: 520),
              child: GlassCard(
                blur: 24,
                opacity: 0.96,
                borderRadius: BorderRadius.circular(20),
                borderColor: AppColors.glassBorderHighlight,
                padding: EdgeInsets.all(isMobile ? 18 : 26),
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
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.edit_location_alt_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Edit Branch & Geofence',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 15 : 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      GlassTextField(
                        label: 'Branch Name *',
                        hintText: 'e.g. Branch Alpha',
                        controller: nameCtrl,
                      ),
                      const SizedBox(height: 14),
                      GlassTextField(
                        label: 'Branch Code',
                        hintText: 'e.g. BR-ALPHA',
                        controller: codeCtrl,
                      ),
                      const SizedBox(height: 14),
                      GlassTextField(
                        label: 'Address / Campus Location',
                        hintText: 'e.g. 5th Avenue, Suite 400',
                        controller: addressCtrl,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 18),

                      // Geofence configuration container
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.share_location_rounded, size: 18, color: AppColors.neonViolet),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Office Geofence Radius',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: geofenceEnabled,
                                  activeThumbColor: AppColors.neonCyan,
                                  onChanged: (val) => setDlgState(() => geofenceEnabled = val),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: GlassTextField(
                                    label: 'Latitude (GPS)',
                                    hintText: 'e.g. 12.9716000',
                                    controller: latCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: GlassTextField(
                                    label: 'Longitude (GPS)',
                                    hintText: 'e.g. 77.5946000',
                                    controller: lngCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.neonCyan,
                                      side: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                                    ),
                                    onPressed: () => _fetchCurrentLocation(latCtrl, lngCtrl, setDlgState, ctx),
                                    icon: const Icon(Icons.my_location_rounded, size: 16),
                                    label: Text(
                                      'Take Current GPS',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.neonViolet.withValues(alpha: 0.25),
                                      foregroundColor: Colors.white,
                                      side: BorderSide(color: AppColors.neonViolet.withValues(alpha: 0.6)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _openMapPicker(latCtrl, lngCtrl, radiusCtrl, setDlgState, ctx),
                                    icon: const Icon(Icons.map_rounded, size: 16, color: AppColors.neonCyan),
                                    label: Text(
                                      'Pick on Map',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GlassTextField(
                              label: 'Fence Radius (meters)',
                              hintText: '100',
                              controller: radiusCtrl,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.only(top: 14),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0x33D4AF37), width: 1.0),
                          ),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            GlassSecondaryButton(
                              text: 'Cancel',
                              onPressed: () => Navigator.pop(ctx),
                            ),
                            GradientPrimaryButton(
                              text: 'Save Changes',
                              icon: Icons.check_rounded,
                              onPressed: () async {
                                if (nameCtrl.text.trim().isEmpty) return;
                                final p = context.read<LeadProvider>();
                                final nav = Navigator.of(ctx);
                                final scaf = ScaffoldMessenger.of(context);
                                final ok = await p.updateBranch(
                                  branchId: branch.id,
                                  name: nameCtrl.text.trim(),
                                  code: codeCtrl.text.trim(),
                                  address: addressCtrl.text.trim(),
                                  latitude: double.tryParse(latCtrl.text.trim()),
                                  longitude: double.tryParse(lngCtrl.text.trim()),
                                  radiusMeters: int.tryParse(radiusCtrl.text.trim()) ?? 100,
                                  geofenceEnabled: geofenceEnabled,
                                );
                                if (ok) {
                                  nav.pop();
                                  scaf.showSnackBar(
                                    const SnackBar(
                                      content: Text('Branch updated successfully!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
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

  void _showDepartmentDialog({DepartmentModel? department}) {
    final nameCtrl = TextEditingController(text: department?.name ?? '');
    final codeCtrl = TextEditingController(text: department?.code ?? '');
    final descCtrl = TextEditingController(text: department?.description ?? '');
    String attendanceMode = department?.attendanceMode ?? 'GEOFENCE';
    List<String> selectedBranches = List<String>.from(department?.allowedBranches ?? []);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) {
        final isMobile = ResponsiveLayout.isMobile(ctx);
        final leadP = context.read<LeadProvider>();
        return StatefulBuilder(
          builder: (context, setDlgState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: GlassCard(
                blur: 24,
                opacity: 0.96,
                borderRadius: BorderRadius.circular(20),
                borderColor: AppColors.glassBorderHighlight,
                padding: EdgeInsets.all(isMobile ? 18 : 26),
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
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.corporate_fare_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              department == null ? 'Add Department' : 'Edit Department',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 15 : 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      GlassTextField(
                        label: 'Department Name *',
                        hintText: 'e.g. Telecalling, Field Sales, Technical',
                        controller: nameCtrl,
                      ),
                      const SizedBox(height: 14),
                      GlassTextField(
                        label: 'Department Code',
                        hintText: 'e.g. SALES-FIELD or TC-HQ',
                        controller: codeCtrl,
                      ),
                      const SizedBox(height: 14),
                      GlassTextField(
                        label: 'Description',
                        hintText: 'Scope and responsibilities of this team',
                        controller: descCtrl,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 18),

                      // Attendance Mode selector
                      Text(
                        'Attendance & Location Tracking Mode',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(() => attendanceMode = 'GEOFENCE'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: attendanceMode == 'GEOFENCE'
                                      ? AppColors.neonViolet.withValues(alpha: 0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: attendanceMode == 'GEOFENCE'
                                        ? AppColors.neonViolet
                                        : const Color(0xFFE2E8F0),
                                    width: attendanceMode == 'GEOFENCE' ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.business_rounded,
                                          size: 16,
                                          color: attendanceMode == 'GEOFENCE'
                                              ? AppColors.neonViolet
                                              : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Office Geo-fence',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: attendanceMode == 'GEOFENCE'
                                                ? AppColors.neonViolet
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Requires staff within radius of allowed branches',
                                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () => setDlgState(() => attendanceMode = 'FIELD_STAFF'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: attendanceMode == 'FIELD_STAFF'
                                      ? AppColors.neonCyan.withValues(alpha: 0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: attendanceMode == 'FIELD_STAFF'
                                        ? AppColors.neonCyan
                                        : const Color(0xFFE2E8F0),
                                    width: attendanceMode == 'FIELD_STAFF' ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.directions_car_rounded,
                                          size: 16,
                                          color: attendanceMode == 'FIELD_STAFF'
                                              ? AppColors.neonCyan
                                              : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Field Staff Track',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: attendanceMode == 'FIELD_STAFF'
                                                ? AppColors.neonCyan
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dynamic GPS punch + logs multiple client visits',
                                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Multi-Branch Selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Allowed Branches for Check-In (${selectedBranches.length}/${leadP.branches.length})',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setDlgState(() {
                                if (selectedBranches.length == leadP.branches.length) {
                                  selectedBranches.clear();
                                } else {
                                  selectedBranches = leadP.branches.map((b) => b.id).toList();
                                }
                              });
                            },
                            child: Text(
                              selectedBranches.length == leadP.branches.length ? 'Clear All' : 'Select All',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.neonCyan),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: leadP.branches.map((b) {
                          final isSelected = selectedBranches.contains(b.id);
                          return FilterChip(
                            selected: isSelected,
                            label: Text(b.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                            selectedColor: AppColors.neonViolet.withValues(alpha: 0.15),
                            checkmarkColor: AppColors.neonViolet,
                            backgroundColor: Colors.white,
                            side: BorderSide(color: isSelected ? AppColors.neonViolet : const Color(0xFFE2E8F0)),
                            onSelected: (val) {
                              setDlgState(() {
                                if (val) {
                                  selectedBranches.add(b.id);
                                } else {
                                  selectedBranches.remove(b.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.only(top: 14),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0x33D4AF37), width: 1.0),
                          ),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            GlassSecondaryButton(
                              text: 'Cancel',
                              onPressed: () => Navigator.pop(ctx),
                            ),
                            GradientPrimaryButton(
                              text: department == null ? 'Create Department' : 'Save Changes',
                              icon: Icons.check_rounded,
                              onPressed: () async {
                                if (nameCtrl.text.trim().isEmpty) return;
                                final deptP = context.read<DepartmentProvider>();
                                final nav = Navigator.of(ctx);
                                final scaf = ScaffoldMessenger.of(context);
                                bool ok = false;
                                if (department == null) {
                                  final res = await deptP.createDepartment(
                                    name: nameCtrl.text.trim(),
                                    code: codeCtrl.text.trim(),
                                    description: descCtrl.text.trim(),
                                    attendanceMode: attendanceMode,
                                    allowedBranches: selectedBranches,
                                  );
                                  ok = res != null;
                                } else {
                                  ok = await deptP.updateDepartment(
                                    departmentId: department.id,
                                    name: nameCtrl.text.trim(),
                                    code: codeCtrl.text.trim(),
                                    description: descCtrl.text.trim(),
                                    attendanceMode: attendanceMode,
                                    allowedBranches: selectedBranches,
                                  );
                                }
                                if (ok) {
                                  nav.pop();
                                  scaf.showSnackBar(
                                    SnackBar(
                                      content: Text(department == null ? 'Department created successfully!' : 'Department updated!'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
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

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedColor = '#2563EB';
    final colors = [
      '#2563EB',
      '#10B981',
      '#F59E0B',
      '#EF4444',
      '#06B6D4',
      '#8B5CF6',
      '#EC4899',
      '#3B82F6',
    ];

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
              constraints: const BoxConstraints(maxWidth: 480),
              child: GlassCard(
                blur: 24,
                opacity: 0.96,
                borderRadius: BorderRadius.circular(20),
                borderColor: AppColors.glassBorderHighlight,
                padding: EdgeInsets.all(isMobile ? 18 : 26),
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
                            child: const Icon(
                              Icons.category_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Add Lead Category',
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 15 : 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          DialogCloseButton(onPressed: () => Navigator.pop(ctx)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      GlassTextField(
                        label: 'Category Name *',
                        hintText: 'e.g. Academy Student or Enterprise Client',
                        controller: nameCtrl,
                      ),
                      const SizedBox(height: 14),
                      GlassTextField(
                        label: 'Description',
                        hintText:
                            'e.g. Prospects interested in semester admissions',
                        controller: descCtrl,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Accent Color',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: colors.map((c) {
                          final isSelected = selectedColor == c;
                          final col = Color(int.parse(c.replaceAll('#', '0xFF')));
                          return InkWell(
                            onTap: () => setDlgState(() => selectedColor = c),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: col.withValues(alpha: 0.6),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.only(top: 14),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0x33D4AF37), width: 1.0),
                          ),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            GlassSecondaryButton(
                              text: 'Cancel',
                              onPressed: () => Navigator.pop(ctx),
                            ),
                            GradientPrimaryButton(
                              text: 'Create Category',
                              icon: Icons.check_rounded,
                              gradient: AppColors.cyanGradient,
                              onPressed: () async {
                                if (nameCtrl.text.trim().isEmpty) return;
                                final p = context.read<LeadProvider>();
                                final nav = Navigator.of(ctx);
                                final scaf = ScaffoldMessenger.of(context);
                                final ok = await p.createCategory(
                                  name: nameCtrl.text.trim(),
                                  description: descCtrl.text.trim(),
                                  color: selectedColor,
                                );
                                if (ok) {
                                  nav.pop();
                                  scaf.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Category created successfully!',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
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

  IconData _getCategoryIcon(String catName) {
    switch (catName) {
      case 'Lead Management':
        return Icons.people_alt_rounded;
      case 'Calling Tasks & Execution':
        return Icons.phone_forwarded_rounded;
      case 'Telephony & Recordings':
        return Icons.headset_mic_rounded;
      case 'Attendance & Field Operations':
        return Icons.pin_drop_rounded;
      case 'Branches & Organization':
        return Icons.apartment_rounded;
      case 'Analytics & Reporting':
        return Icons.insights_rounded;
      default:
        return Icons.security_rounded;
    }
  }

  void _showRoleDialog({RoleModel? role}) {
    final nameCtrl = TextEditingController(text: role?.name ?? '');
    final codeCtrl = TextEditingController(text: role?.code ?? '');
    final descCtrl = TextEditingController(text: role?.description ?? '');
    final Set<String> selectedPermissions = Set<String>.from(role?.permissions ?? []);
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
              constraints: const BoxConstraints(maxWidth: 680, maxHeight: 800),
              child: GlassCard(
                blur: 24,
                opacity: 0.96,
                borderRadius: BorderRadius.circular(20),
                borderColor: AppColors.glassBorderHighlight,
                padding: EdgeInsets.all(isMobile ? 18 : 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.security_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role == null ? 'Create Custom Role' : 'Edit Role & Permissions',
                                style: GoogleFonts.inter(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Configure dynamic role permissions and functionality access',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: GlassTextField(
                                    label: 'Role Name *',
                                    hintText: 'e.g. Senior Telecaller, Auditor',
                                    controller: nameCtrl,
                                    prefixIcon: const Icon(Icons.badge_rounded, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: GlassTextField(
                                    label: 'Role Code',
                                    hintText: 'e.g. SR_TC, AUDITOR',
                                    controller: codeCtrl,
                                    prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            GlassTextField(
                              label: 'Description',
                              hintText: 'Describe responsibilities and level of access...',
                              controller: descCtrl,
                              maxLines: 2,
                              prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Functional Permissions',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.neonViolet.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        '${selectedPermissions.length} Enabled',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.neonViolet,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setDlgState(() {
                                          for (final entry in PermissionCatalog.categorizedPermissions.values) {
                                            for (final p in entry) {
                                              selectedPermissions.add(p['key']!);
                                            }
                                          }
                                        });
                                      },
                                      child: Text(
                                        'Select All',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neonCyan),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setDlgState(() {
                                          selectedPermissions.clear();
                                        });
                                      },
                                      child: Text(
                                        'Clear All',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neonCoral),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...PermissionCatalog.categorizedPermissions.entries.map((cat) {
                              final catName = cat.key;
                              final perms = cat.value;
                              final allChecked = perms.every((p) => selectedPermissions.contains(p['key']));
                              final someChecked = perms.any((p) => selectedPermissions.contains(p['key']));

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: someChecked
                                        ? AppColors.neonCyan.withValues(alpha: 0.4)
                                        : AppColors.glassBorder,
                                  ),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _getCategoryIcon(catName),
                                              size: 16,
                                              color: someChecked ? AppColors.neonCyan : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              catName,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        ),
                                        InkWell(
                                          onTap: () {
                                            setDlgState(() {
                                              if (allChecked) {
                                                for (final p in perms) {
                                                  selectedPermissions.remove(p['key']);
                                                }
                                              } else {
                                                for (final p in perms) {
                                                  selectedPermissions.add(p['key']!);
                                                }
                                              }
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            child: Text(
                                              allChecked ? 'Deselect Domain' : 'Select Domain',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.neonCyan,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: perms.map((p) {
                                        final isChecked = selectedPermissions.contains(p['key']);
                                        return InkWell(
                                          onTap: () {
                                            setDlgState(() {
                                              if (isChecked) {
                                                selectedPermissions.remove(p['key']);
                                              } else {
                                                selectedPermissions.add(p['key']!);
                                              }
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(10),
                                          child: Container(
                                            width: isMobile ? double.infinity : 280,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isChecked
                                                  ? AppColors.neonViolet.withValues(alpha: 0.12)
                                                  : Colors.white.withValues(alpha: 0.03),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isChecked
                                                    ? AppColors.neonViolet.withValues(alpha: 0.6)
                                                    : AppColors.glassBorder,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Checkbox(
                                                  value: isChecked,
                                                  activeColor: AppColors.neonViolet,
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  visualDensity: VisualDensity.compact,
                                                  onChanged: (val) {
                                                    setDlgState(() {
                                                      if (val == true) {
                                                        selectedPermissions.add(p['key']!);
                                                      } else {
                                                        selectedPermissions.remove(p['key']);
                                                      }
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        p['label'] ?? '',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: isChecked ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                                        ),
                                                      ),
                                                      Text(
                                                        p['desc'] ?? '',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 10,
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
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.only(top: 14),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0x33D4AF37), width: 1.0),
                        ),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          GlassSecondaryButton(
                            text: 'Cancel',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                          GradientPrimaryButton(
                            text: role == null ? 'Create Role' : 'Save Changes',
                            icon: Icons.check_rounded,
                            gradient: AppColors.primaryGradient,
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (nameCtrl.text.trim().isEmpty) return;
                                    setDlgState(() => isSubmitting = true);
                                    final roleP = context.read<RoleProvider>();
                                    final nav = Navigator.of(ctx);
                                    final scaf = ScaffoldMessenger.of(context);

                                    bool success = false;
                                    if (role == null) {
                                      final created = await roleP.createRole(
                                        name: nameCtrl.text.trim(),
                                        code: codeCtrl.text.trim(),
                                        description: descCtrl.text.trim(),
                                        permissions: selectedPermissions.toList(),
                                      );
                                      success = created != null;
                                    } else {
                                      success = await roleP.updateRole(
                                        roleId: role.id,
                                        name: nameCtrl.text.trim(),
                                        code: codeCtrl.text.trim(),
                                        description: descCtrl.text.trim(),
                                        permissions: selectedPermissions.toList(),
                                      );
                                    }

                                    setDlgState(() => isSubmitting = false);
                                    if (success) {
                                      roleP.fetchRoles();
                                      nav.pop();
                                      scaf.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            role == null
                                                ? 'Custom role created successfully!'
                                                : 'Role updated successfully!',
                                          ),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    } else if (roleP.errorMessage != null) {
                                      scaf.showSnackBar(
                                        SnackBar(
                                          content: Text(roleP.errorMessage!),
                                          backgroundColor: AppColors.neonCoral,
                                        ),
                                      );
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
        );
      },
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF2563EB);
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isSuperAdmin = user?.isSuperAdmin ?? false;
    final canManageBranches = isSuperAdmin || (user?.canManageBranches ?? (user?.hasMenuPermission('branches') ?? false));

    if (!canManageBranches) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassCard(
              padding: const EdgeInsets.all(36),
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Icon(Icons.lock_rounded, color: Color(0xFFDC2626), size: 40),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Multi-Branch Management Locked',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your company plan does not have permission to manage branches. Access to this module is strictly controlled by the platform Super Administrator.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  GradientPrimaryButton(
                    text: 'Return to Dashboard',
                    icon: Icons.arrow_back_rounded,
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final leadProvider = context.watch<LeadProvider>();
    final empProvider = context.watch<EmployeeProvider>();
    final deptProvider = context.watch<DepartmentProvider>();
    final roleProvider = context.watch<RoleProvider>();
    final compProvider = context.watch<CompanyProvider>();
    final isMobile = ResponsiveLayout.isMobile(context);

    final branches = leadProvider.branches.where((b) {
      if (_searchQuery.isEmpty) return true;
      return b.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          b.code.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final categories = leadProvider.categories.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.description.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

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
              // Header Bar with Back Button
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
                              'Branches, Geofence & Structure',
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
                              'Organize branch GPS geofences, departments, and lead categories',
                              style: GoogleFonts.inter(
                                fontSize: 12,
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
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      GradientPrimaryButton(
                        text: 'Add Branch',
                        icon: Icons.add_business_rounded,
                        onPressed: _showAddBranchDialog,
                      ),
                      GlassSecondaryButton(
                        text: 'Add Department',
                        icon: Icons.corporate_fare_rounded,
                        onPressed: () => _showDepartmentDialog(),
                      ),
                      GlassSecondaryButton(
                        text: 'Add Custom Role',
                        icon: Icons.security_rounded,
                        onPressed: () => _showRoleDialog(),
                      ),
                      GlassSecondaryButton(
                        text: 'Add Category',
                        icon: Icons.add_circle_outline_rounded,
                        onPressed: _showAddCategoryDialog,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary Metrics Row
              if (isMobile)
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'Branches',
                        '${leadProvider.branches.length}',
                        Icons.storefront_rounded,
                        AppColors.neonViolet,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        'Depts',
                        '${deptProvider.departments.length}',
                        Icons.corporate_fare_rounded,
                        AppColors.neonCyan,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        'Roles',
                        '${roleProvider.roles.length}',
                        Icons.security_rounded,
                        const Color(0xFFF59E0B),
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricTile(
                        'Staff',
                        '${empProvider.employees.length}',
                        Icons.badge_rounded,
                        const Color(0xFF10B981),
                        compact: true,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'Total Branches',
                        '${leadProvider.branches.length}',
                        Icons.storefront_rounded,
                        AppColors.neonViolet,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        'Departments',
                        '${deptProvider.departments.length}',
                        Icons.corporate_fare_rounded,
                        AppColors.neonCyan,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        'Custom Roles',
                        '${roleProvider.roles.length}',
                        Icons.security_rounded,
                        const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricTile(
                        'Assigned Staff',
                        '${empProvider.employees.length}',
                        Icons.badge_rounded,
                        const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 18),

              // Tabs Toolbar
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
                  labelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  isScrollable: isMobile,
                  tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
                  tabs: [
                    Tab(text: 'BRANCHES (${leadProvider.branches.length})'),
                    Tab(text: 'CATEGORIES (${leadProvider.categories.length})'),
                    Tab(text: 'DEPARTMENTS (${deptProvider.departments.length})'),
                    Tab(text: 'ROLES & RBAC (${roleProvider.roles.length})'),
                    Tab(text: 'RULES & PAYROLL (${compProvider.companyRules.length})'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Content Area
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBranchList(branches, leadProvider),
                    _buildCategoryList(categories, leadProvider),
                    _buildDepartmentList(deptProvider.departments, deptProvider, leadProvider),
                    _buildRoleList(roleProvider.roles, roleProvider),
                    const CompanyRulesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    String label,
    String value,
    IconData icon,
    Color accent, {
    bool compact = false,
  }) {
    return GlassCard(
      blur: 16,
      opacity: 0.12,
      borderRadius: BorderRadius.circular(16),
      borderColor: AppColors.glassBorder,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 10 : 14),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 7 : 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: accent, size: compact ? 16 : 20),
          ),
          SizedBox(width: compact ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 15 : 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 10 : 11,
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
    );
  }

  Widget _buildBranchList(
    List<BranchModel> branches,
    LeadProvider leadProvider,
  ) {
    if (branches.isEmpty) {
      return Center(
        child: GlassCard(
          blur: 16,
          opacity: 0.12,
          borderColor: AppColors.glassBorder,
          padding: const EdgeInsets.all(32),
          child: Text(
            'No branches created yet.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: branches.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final b = branches[i];
        return GlassCard(
          blur: 18,
          opacity: 0.12,
          borderRadius: BorderRadius.circular(16),
          borderColor: AppColors.glassBorder,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (b.code.isNotEmpty)
                      Text(
                        'Code: ${b.code}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          color: AppColors.neonCyan,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (b.address.isNotEmpty)
                      Text(
                        b.address,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    if (b.latitude != null && b.longitude != null)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (b.geofenceEnabled ? AppColors.neonCyan : Colors.grey).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: (b.geofenceEnabled ? AppColors.neonCyan : Colors.grey).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.share_location_rounded, size: 12, color: b.geofenceEnabled ? AppColors.neonCyan : Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${b.radiusMeters}m Geofence (${b.latitude!.toStringAsFixed(3)}, ${b.longitude!.toStringAsFixed(3)})',
                              style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w600, color: b.geofenceEnabled ? AppColors.neonCyan : Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '⚠️ No GPS Geofence Set',
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.amber.shade800, fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedStatusBadge(
                label: '${b.leadCount} Leads',
                statusColor: AppColors.neonCyan,
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.neonCyan,
                  size: 18,
                ),
                tooltip: 'Edit Branch & Geofence',
                onPressed: () => _showEditBranchDialog(b),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.neonCoral,
                  size: 18,
                ),
                onPressed: () => leadProvider.deleteBranch(b.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDepartmentList(
    List<DepartmentModel> departments,
    DepartmentProvider deptProvider,
    LeadProvider leadProvider,
  ) {
    if (departments.isEmpty) {
      return Center(
        child: GlassCard(
          blur: 16,
          opacity: 0.12,
          borderColor: AppColors.glassBorder,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.corporate_fare_rounded, size: 40, color: Color(0xFF64748B)),
              const SizedBox(height: 12),
              Text(
                'No departments created yet.',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                'Group staff into departments (e.g. Telecalling, Field Sales) to configure dual attendance modes & multi-branch access.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              GradientPrimaryButton(
                text: 'Create Department',
                icon: Icons.add_rounded,
                onPressed: () => _showDepartmentDialog(),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: departments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final d = departments[i];
        final isGeofence = d.isGeofenceMode;
        return GlassCard(
          blur: 18,
          opacity: 0.12,
          borderRadius: BorderRadius.circular(16),
          borderColor: AppColors.glassBorder,
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: isGeofence ? AppColors.primaryGradient : AppColors.cyanGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isGeofence ? Icons.business_rounded : Icons.directions_car_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          d.name,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (d.code.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            d.code,
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              color: AppColors.neonCyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (d.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          d.description,
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isGeofence ? AppColors.neonViolet : AppColors.neonCyan).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: (isGeofence ? AppColors.neonViolet : AppColors.neonCyan).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isGeofence ? Icons.pin_drop_rounded : Icons.route_rounded, size: 12, color: isGeofence ? AppColors.neonViolet : AppColors.neonCyan),
                              const SizedBox(width: 4),
                              Text(
                                isGeofence ? 'Office Geo-fence' : 'Field Staff Tracking',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: isGeofence ? AppColors.neonViolet : AppColors.neonCyan),
                              ),
                            ],
                          ),
                        ),
                        if (d.allowedBranches.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF64748B).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${d.allowedBranches.length} Allowed Branch${d.allowedBranches.length > 1 ? 'es' : ''}',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedStatusBadge(
                label: '${d.memberCount} Staff',
                statusColor: AppColors.neonViolet,
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.neonCyan, size: 18),
                tooltip: 'Edit Department',
                onPressed: () => _showDepartmentDialog(department: d),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.neonCoral, size: 18),
                tooltip: 'Deactivate Department',
                onPressed: () async {
                  await deptProvider.updateDepartment(departmentId: d.id, isActive: false);
                  deptProvider.fetchDepartments();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryList(
    List<LeadCategoryModel> categories,
    LeadProvider leadProvider,
  ) {
    if (categories.isEmpty) {
      return Center(
        child: GlassCard(
          blur: 16,
          opacity: 0.12,
          borderColor: AppColors.glassBorder,
          padding: const EdgeInsets.all(32),
          child: Text(
            'No categories created yet.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final c = categories[i];
        final col = _parseColor(c.color);
        return GlassCard(
          blur: 18,
          opacity: 0.12,
          borderRadius: BorderRadius.circular(16),
          borderColor: AppColors.glassBorder,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: col.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.category_rounded, color: col, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (c.description.isNotEmpty)
                      Text(
                        c.description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedStatusBadge(
                label: '${c.leadCount} Leads',
                statusColor: col,
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.neonCoral,
                  size: 20,
                ),
                onPressed: () => leadProvider.deleteCategory(c.id),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleList(List<RoleModel> roles, RoleProvider roleProvider) {
    if (roleProvider.isLoading && roles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (roles.isEmpty) {
      return Center(
        child: GlassCard(
          blur: 16,
          opacity: 0.12,
          borderColor: AppColors.glassBorder,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security_rounded, size: 48, color: AppColors.neonViolet),
              const SizedBox(height: 12),
              Text(
                'No custom roles created yet.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create custom roles to assign granular functional permissions to employees.',
                style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GradientPrimaryButton(
                text: 'Create First Role',
                icon: Icons.add_moderator_rounded,
                onPressed: () => _showRoleDialog(),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: roles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final r = roles[i];
        final isMobile = ResponsiveLayout.isMobile(ctx);

        return GlassCard(
          blur: 18,
          opacity: 0.14,
          borderRadius: BorderRadius.circular(16),
          borderColor: r.isSystemDefault
              ? AppColors.neonCyan.withValues(alpha: 0.35)
              : AppColors.glassBorder,
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: r.isSystemDefault
                      ? AppColors.primaryGradient
                      : LinearGradient(
                          colors: [
                            AppColors.neonCyan.withValues(alpha: 0.25),
                            AppColors.neonViolet.withValues(alpha: 0.25),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.neonViolet.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  r.isSystemDefault ? Icons.verified_user_rounded : Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          r.name,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        if (r.code.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: Text(
                              r.code,
                              style: GoogleFonts.robotoMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        if (r.isSystemDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.neonCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              'DEFAULT ROLE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.neonCyan,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (r.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        r.description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.neonViolet.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.neonViolet.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            '${r.permissions.length} Permissions Active',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neonViolet,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            '${r.userCount} Assigned Staff',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.neonCyan, size: 20),
                    tooltip: 'Edit Role & Permissions',
                    onPressed: () => _showRoleDialog(role: r),
                  ),
                  if (!r.isSystemDefault)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.neonCoral, size: 20),
                      tooltip: 'Delete Role',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: const Color(0xFF1E293B),
                            title: Text('Delete Role?', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700)),
                            content: Text(
                              'Are you sure you want to delete role "${r.name}"? Employees with this role will lose its permissions.',
                              style: GoogleFonts.inter(color: AppColors.textSecondary),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Delete', style: TextStyle(color: AppColors.neonCoral)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await roleProvider.deleteRole(r.id);
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
