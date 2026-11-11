import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../core/widgets/glass/app_background.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/callback_provider.dart';
import '../dashboard/admin_dashboard_screen.dart';
import '../dashboard/company_admin_dashboard_screen.dart';
import '../dashboard/telecaller_dashboard_screen.dart';
import '../leads/lead_directory_screen.dart';
import '../leads/add_lead_dialog.dart';
import '../callbacks/callback_screen.dart';
import '../calls/call_history_screen.dart';
import '../calls/call_recordings_screen.dart';
import '../branches/branch_management_screen.dart';
import '../tasks/calling_tasks_screen.dart';
import '../employees/employee_management_screen.dart';
import '../attendance/attendance_screen.dart';
import '../companies/company_directory_screen.dart';
import '../admin/plan_management_screen.dart';
import '../admin/platform_billing_screen.dart';
import '../billing/invoice_list_screen.dart';
import '../auth/login_screen.dart';
import '../notifications/notification_drawer.dart';
import '../../core/widgets/brand_logo.dart';
import '../../routes/app_routes.dart';

class MainLayout extends StatefulWidget {
  final String? initialRouteKey;
  const MainLayout({super.key, this.initialRouteKey});

  static bool goToDashboard(BuildContext context) {
    final state = context.findAncestorStateOfType<_MainLayoutState>();
    if (state != null && state._selectedIndex != 0) {
      state._resetToDashboard();
      return true;
    }
    return false;
  }

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _initialRouteApplied = false;
  String? _lastUserId;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();

  void _resetToDashboard() {
    if (mounted) {
      setState(() => _selectedIndex = 0);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        context.read<NotificationProvider>().fetchNotifications();
        context.read<CallbackProvider>().checkReminders();
      }
    });
  }

  Future<void> _performLogout(AuthProvider auth, {bool isDrawer = false}) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (isDrawer && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    await auth.logout();
    if (!mounted) return;
    setState(() {
      _selectedIndex = 0;
      _lastUserId = null;
    });
    rootNav.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddLeadDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const AddLeadDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (!auth.isAuthenticated || user == null) {
      return const LoginScreen();
    }

    if (_lastUserId != user.id) {
      _lastUserId = user.id;
      _selectedIndex = 0;
      _initialRouteApplied = false;
    }

    final isTelecaller = user.isEmployee;
    final isSuperAdmin = user.isSuperAdmin;
    final isCompanyAdmin = user.isCompanyAdmin || user.isManager;
    final isMobile = ResponsiveLayout.isMobile(context);

    // Build nav items dynamically with categorized sections
    final navItems = <_NavItem>[];

    if (isSuperAdmin) {
      // ==========================================
      // SUPER ADMIN PLATFORM SUITE
      // Only manages Companies, Plans, Billing, Permissions & Platform Control
      // ==========================================
      navItems.addAll([
        _NavItem(
          section: 'PLATFORM CONTROL',
          title: 'Platform Hub',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          routeKey: 'dashboard',
          screen: const AdminDashboardScreen(),
        ),
        _NavItem(
          section: 'PLATFORM CONTROL',
          title: 'Companies (Tenants)',
          icon: Icons.business_outlined,
          activeIcon: Icons.business_rounded,
          badge: 'Tenants',
          badgeColor: AppColors.goldLuxury,
          routeKey: 'companies',
          screen: const CompanyDirectoryScreen(),
        ),
        _NavItem(
          section: 'SUBSCRIPTION & BILLING',
          title: 'Subscription Plans',
          icon: Icons.workspace_premium_outlined,
          activeIcon: Icons.workspace_premium_rounded,
          badge: 'Pricing',
          badgeColor: const Color(0xFF10B981),
          routeKey: 'plans',
          screen: const PlanManagementScreen(),
        ),
        _NavItem(
          section: 'SUBSCRIPTION & BILLING',
          title: 'Platform Billing',
          icon: Icons.monetization_on_outlined,
          activeIcon: Icons.monetization_on_rounded,
          badge: 'MRR',
          badgeColor: AppColors.goldLuxury,
          routeKey: 'billing',
          screen: const PlatformBillingScreen(),
        ),
        _NavItem(
          section: 'GOVERNANCE',
          title: 'Audit Trails',
          icon: Icons.manage_history_rounded,
          activeIcon: Icons.manage_history_rounded,
          routeKey: 'audit',
          screen: const AdminDashboardScreen(),
        ),
      ]);
    } else {
      // ==========================================
      // TENANT COMPANY SUITE (COMPANY ADMIN & TELECALLERS)
      // Strictly filtered by Super Admin-assigned companyAllowedMenus!
      // ==========================================
      navItems.add(
        _NavItem(
          section: 'CORE HUB',
          title: isCompanyAdmin ? 'Company Dashboard' : 'My Workspace',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          routeKey: 'dashboard',
          screen: isCompanyAdmin
              ? const CompanyAdminDashboardScreen()
              : const TelecallerDashboardScreen(),
        ),
      );

      // Multi-Branch Management (Strictly checked against permission!)
      if (user.hasMenuPermission('branches') && !isTelecaller) {
        navItems.add(
          _NavItem(
            section: 'ORGANIZATION',
            title: 'Branches & Divisions',
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront_rounded,
            routeKey: 'branches',
            screen: const BranchManagementScreen(),
          ),
        );
      }

      // Telecaller Team
      if (user.hasMenuPermission('employees') && !isTelecaller) {
        navItems.add(
          _NavItem(
            section: 'ORGANIZATION',
            title: 'Telecaller Team',
            icon: Icons.people_outline_rounded,
            activeIcon: Icons.people_rounded,
            routeKey: 'employees',
            screen: const EmployeeManagementScreen(),
          ),
        );
      }

      // Stepz Attendance & Geofencing
      if (user.hasMenuPermission('attendance')) {
        navItems.add(
          _NavItem(
            section: 'ORGANIZATION',
            title: isTelecaller ? 'My Attendance & Punch' : 'Attendance & Geofencing',
            icon: Icons.fingerprint_outlined,
            activeIcon: Icons.fingerprint_rounded,
            badge: 'GPS',
            badgeColor: AppColors.neonCyan,
            routeKey: 'attendance',
            screen: const AttendanceScreen(),
          ),
        );
      }

      // Lead Workspace
      if (user.hasMenuPermission('leads')) {
        navItems.add(
          _NavItem(
            section: 'LEAD WORKSPACE',
            title: isTelecaller ? 'My Assigned Leads' : 'Company Leads',
            icon: Icons.contact_phone_outlined,
            activeIcon: Icons.contact_phone_rounded,
            routeKey: 'leads',
            screen: const LeadDirectoryScreen(),
          ),
        );
      }

      // Calling Tasks
      if (user.hasMenuPermission('tasks')) {
        navItems.add(
          _NavItem(
            section: 'LEAD WORKSPACE',
            title: isTelecaller ? 'My Calling Tasks' : 'Calling Tasks',
            icon: Icons.task_alt_outlined,
            activeIcon: Icons.task_alt_rounded,
            routeKey: 'tasks',
            screen: const CallingTasksScreen(),
          ),
        );
      }

      // Sales & Billing (Quotations, Tax Invoices, Receipts)
      navItems.add(
        _NavItem(
          section: 'SALES & BILLING',
          title: 'Quotations & Estimates',
          icon: Icons.request_quote_outlined,
          activeIcon: Icons.request_quote_rounded,
          badge: 'Estimate',
          badgeColor: const Color(0xFFD97706),
          routeKey: 'quotations',
          screen: const InvoiceListScreen(initialTab: 1),
        ),
      );

      navItems.add(
        _NavItem(
          section: 'SALES & BILLING',
          title: isTelecaller ? 'Bills & Invoices' : 'Bills & Tax Invoices',
          icon: Icons.receipt_long_outlined,
          activeIcon: Icons.receipt_long_rounded,
          badge: 'Fixed',
          badgeColor: const Color(0xFF10B981),
          routeKey: 'billing',
          screen: const InvoiceListScreen(initialTab: 0),
        ),
      );

      // Telephony Hub: Audio Recordings
      if (user.hasMenuPermission('recordings')) {
        navItems.add(
          _NavItem(
            section: 'TELEPHONY HUB',
            title: isTelecaller ? 'My Call Recordings' : 'Call Recordings',
            icon: Icons.graphic_eq_outlined,
            activeIcon: Icons.graphic_eq_rounded,
            badge: 'Audio',
            badgeColor: AppColors.emerald,
            routeKey: 'recordings',
            screen: const CallRecordingsScreen(),
          ),
        );
      }

      // Priority Callbacks
      if (user.hasMenuPermission('callbacks')) {
        navItems.add(
          _NavItem(
            section: 'TELEPHONY HUB',
            title: isTelecaller ? 'My Callbacks' : 'Scheduled Callbacks',
            icon: Icons.alarm_on_outlined,
            activeIcon: Icons.alarm_on_rounded,
            badge: 'Priority',
            badgeColor: AppColors.goldLuxury,
            routeKey: 'callbacks',
            screen: const CallbackScreen(),
          ),
        );
      }

      // Call History Logs
      if (user.hasMenuPermission('call_history')) {
        navItems.add(
          _NavItem(
            section: 'TELEPHONY HUB',
            title: isTelecaller ? 'My Call History' : 'Call History Logs',
            icon: Icons.history_toggle_off_rounded,
            activeIcon: Icons.history_rounded,
            routeKey: 'call_history',
            screen: const CallHistoryScreen(),
          ),
        );
      }

      if (!isTelecaller) {
        navItems.add(
          _NavItem(
            section: 'ADMINISTRATION',
            title: 'Company Settings',
            icon: Icons.tune_rounded,
            activeIcon: Icons.tune_rounded,
            routeKey: 'settings',
            screen: const BranchManagementScreen(),
          ),
        );
      }
    }

    if (!_initialRouteApplied && widget.initialRouteKey != null) {
      _initialRouteApplied = true;
      final targetIdx = navItems.indexWhere((it) => it.routeKey == widget.initialRouteKey);
      if (targetIdx != -1) {
        _selectedIndex = targetIdx;
      }
    }

    if (_selectedIndex >= navItems.length) {
      _selectedIndex = 0;
    }

    final notifProvider = context.watch<NotificationProvider>();
    final activeNavItem = navItems[_selectedIndex];

    return AppBackground(
      preset: AppBackgroundPreset.cleanEnterprise,
      animateBlobs: true,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawer: isMobile
            ? Drawer(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: _buildLuxurySidebar(
                  context,
                  navItems,
                  user,
                  auth,
                  isSuperAdmin,
                  isDrawer: true,
                ),
              )
            : null,
        endDrawer: const NotificationDrawer(),
        body: Row(
          children: [
            // Desktop Executive Navigation Sidebar in Crisp White & Gold/Emerald
            if (!isMobile)
              _buildLuxurySidebar(
                context,
                navItems,
                user,
                auth,
                isSuperAdmin,
              ),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Luxury Glass Top Bar (Rendered everywhere)
                  _buildLuxuryTopBar(
                    context,
                    navItems,
                    isMobile,
                    notifProvider,
                    auth,
                    isCompanyAdmin,
                  ),

                  // Active Screen Body (strip already-consumed status/nav bar padding & viewPadding)
                  Expanded(
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      removeBottom: isMobile,
                      child: MediaQuery.removeViewPadding(
                        context: context,
                        removeTop: true,
                        removeBottom: isMobile,
                        child: activeNavItem.screen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: isMobile
            ? _buildMobileLuxuryBottomBar(navItems)
            : null,
      ),
    );
  }

  // ==========================================
  // LUXURY LIGHT GREY & GOLD/EMERALD SIDEBAR
  // ==========================================
  Widget _buildLuxurySidebar(
    BuildContext context,
    List<_NavItem> navItems,
    dynamic user,
    AuthProvider auth,
    bool isSuperAdmin, {
    bool isDrawer = false,
  }) {
    String currentSection = '';
    final isCompanyAdmin = (user?.isCompanyAdmin ?? false) || (user?.isManager ?? false);

    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          right: BorderSide(color: Color(0x33D4AF37), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(3, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Enterprise Brand Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TelecallerLogo(
                  isDark: false,
                  iconSize: 22,
                  titleSize: 16,
                  showSubtitle: true,
                ),
                const SizedBox(height: 14),

                // Active Workspace Card with Champagne Gold & Emerald Accents
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7).withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.40),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFF047857),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 13,
                          color: Color(0xFFFEF3C7),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isSuperAdmin
                                  ? 'PLATFORM HQ'
                                  : (user?.companyName?.toUpperCase() ?? 'MY WORKSPACE'),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isSuperAdmin
                                  ? 'Tier-1 Root Authority'
                                  : 'Enterprise Multi-Tenant',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5.5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xFF047857).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            color: Color(0xFFE2E8F0),
            height: 1,
            thickness: 1,
          ),

          // 2. Navigation Items List with Categorized Headers
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isActive = _selectedIndex == index;
                final showSectionHeader = item.section != currentSection;
                if (showSectionHeader) {
                  currentSection = item.section;
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showSectionHeader) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(10, index == 0 ? 4 : 16, 10, 6),
                        child: Text(
                          item.section,
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB45309), // Warm gold label
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedIndex = index);
                          if (isDrawer) {
                            Navigator.of(context).pop();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF064E3B),
                                      Color(0xFF047857),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isActive
                                ? null
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isActive
                                ? Border.all(
                                    color: const Color(0xFFD4AF37),
                                    width: 1.0,
                                  )
                                : Border.all(
                                    color: Colors.transparent,
                                    width: 1.0,
                                  ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF047857).withValues(alpha: 0.32),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isActive ? item.activeIcon : item.icon,
                                size: 18,
                                color: isActive
                                    ? Colors.white
                                    : const Color(0xFF475569),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.8,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              if (item.badge != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (item.badgeColor ?? AppColors.goldLuxury)
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (item.badgeColor ?? AppColors.goldLuxury)
                                          .withValues(alpha: 0.45),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    item.badge!,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: item.badgeColor ?? const Color(0xFFB45309),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              if (isActive)
                                Container(
                                  width: 4,
                                  height: 14,
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const Divider(
            color: Color(0xFFE2E8F0),
            height: 1,
            thickness: 1,
          ),

          // 3. User Profile Footer Card in Pure White & Gold
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF047857), Color(0xFF065F46)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD4AF37),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          (user?.fullName.isNotEmpty == true
                                  ? user!.fullName[0]
                                  : 'U')
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName.isNotEmpty == true
                            ? user!.fullName
                            : 'Executive User',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isSuperAdmin
                            ? 'Super Administrator'
                            : (isCompanyAdmin
                                ? 'Company Admin'
                                : 'Telecaller Agent'),
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF047857),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: Color(0xFFDC2626),
                  ),
                  onPressed: () => _performLogout(auth, isDrawer: isDrawer),
                  tooltip: 'Sign Out',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  // ==========================================
  // LUXURY TOP APP BAR IN WHITE & GOLD
  // ==========================================
  Widget _buildLuxuryTopBar(
    BuildContext context,
    List<_NavItem> navItems,
    bool isMobile,
    NotificationProvider notifProvider,
    AuthProvider auth,
    bool canAddLead,
  ) {
    final activeItem = navItems[_selectedIndex];
    final now = DateTime.now();
    final dateStr = DateFormat('EEE, d MMM').format(now);
    final user = auth.currentUser;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0x33D4AF37), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: isMobile ? 50 : 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          // Left: Mobile Toggle, Back Button or Desktop Breadcrumbs & System Status
          Expanded(
            child: Row(
              children: [
                if (isMobile) ...[
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A), size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              activeItem.title,
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 14.5 : 16.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isMobile) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF047857).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5.5,
                                    height: 5.5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF047857),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '99.98% SLA',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!isMobile)
                        Text(
                          'Telecaller Enterprise • ${activeItem.section}',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
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

          // Center: Global Search Bar (Desktop)
          if (!isMobile)
            Container(
              width: 320,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.search_rounded,
                      size: 17,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Quick search leads, calls, reps...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                        isDense: true,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.40)),
                    ),
                    child: Text(
                      'Ctrl + K',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Right: Date, Quick Action CTA, Notifications, Profile Pill
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMobile) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF047857)),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // Quick Action Button in Imperial Emerald & Gold
              if (canAddLead) ...[
                InkWell(
                  onTap: _openAddLeadDialog,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFFD4AF37), width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF047857).withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                        if (!isMobile) ...[
                          const SizedBox(width: 5),
                          Text(
                            'Add Lead',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // Notification Bell with dynamic unread badge
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        size: 19,
                        color: Color(0xFF1E293B),
                      ),
                      onPressed: () {
                        notifProvider.fetchNotifications();
                        _scaffoldKey.currentState?.openEndDrawer();
                      },
                      padding: EdgeInsets.zero,
                      tooltip: 'Notifications',
                    ),
                  ),
                  if (notifProvider.unreadCount > 0)
                    IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.only(top: 1, right: 1),
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          gradient: AppColors.luxuryGoldGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            '${notifProvider.unreadCount > 9 ? '9+' : notifProvider.unreadCount}',
                            style: const TextStyle(
                              fontSize: 8.5,
                              color: Color(0xFF064E3B),
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),

              // User Avatar Pill with Quick Sign-Out Menu
              PopupMenuButton<String>(
                tooltip: 'Account Menu',
                offset: const Offset(0, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0x33D4AF37)),
                ),
                onSelected: (value) {
                  if (value == 'logout') {
                    _performLogout(auth);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName.isNotEmpty == true ? user!.fullName : 'User',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Text(
                          'Sign Out',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x33D4AF37)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF047857), Color(0xFF065F46)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            (user?.fullName.isNotEmpty == true
                                    ? user!.fullName[0]
                                    : 'U')
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (!isMobile) ...[
                        const SizedBox(width: 7),
                        Text(
                          user?.fullName.isNotEmpty == true
                              ? user!.fullName.split(' ')[0]
                              : 'User',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MOBILE LUXURY BOTTOM NAV BAR
  // ==========================================
  Widget _buildMobileLuxuryBottomBar(List<_NavItem> navItems) {
    final showMore = navItems.length > 5;
    final displayItems = showMore ? navItems.sublist(0, 4) : navItems;
    final int currentNavIndex = _selectedIndex < 4
        ? _selectedIndex
        : (showMore ? 4 : 0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0x33D4AF37), width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: currentNavIndex,
          onTap: (index) {
            if (showMore && index == 4) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              setState(() => _selectedIndex = index);
            }
          },
          selectedItemColor: const Color(0xFF047857),
          unselectedItemColor: const Color(0xFF64748B),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
          items: [
            ...displayItems.map((item) {
              return BottomNavigationBarItem(
                icon: Icon(item.icon, size: 20),
                activeIcon: Icon(item.activeIcon, size: 20),
                label: item.title,
              );
            }),
            if (showMore)
              const BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz_rounded, size: 20),
                activeIcon: Icon(Icons.more_horiz_rounded, size: 20),
                label: 'More',
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String section;
  final String title;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
  final String? badge;
  final Color? badgeColor;
  final String? routeKey;

  _NavItem({
    required this.section,
    required this.title,
    required this.icon,
    required this.activeIcon,
    required this.screen,
    this.badge,
    this.badgeColor,
    this.routeKey,
  });
}
