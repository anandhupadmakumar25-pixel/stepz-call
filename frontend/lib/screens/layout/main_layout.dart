import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/callback_provider.dart';
import '../dashboard/admin_dashboard_screen.dart';
import '../dashboard/telecaller_dashboard_screen.dart';
import '../leads/lead_directory_screen.dart';
import '../callbacks/callback_screen.dart';
import '../calls/call_history_screen.dart';
import '../branches/branch_management_screen.dart';
import '../tasks/calling_tasks_screen.dart';
import '../employees/employee_management_screen.dart';
import '../companies/company_directory_screen.dart';
import '../notifications/notification_drawer.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
      context.read<CallbackProvider>().checkReminders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isTelecaller = user?.isEmployee ?? true;
    final isSuperAdmin = user?.isSuperAdmin ?? false;
    final isMobile = ResponsiveLayout.isMobile(context);

    // Build nav items dynamically based on role
    final navItems = <_NavItem>[
      _NavItem(
        title: 'Dashboard',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        screen: isTelecaller
            ? const TelecallerDashboardScreen()
            : const AdminDashboardScreen(),
      ),
      _NavItem(
        title: isTelecaller ? 'My Leads' : 'Leads Directory',
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        screen: const LeadDirectoryScreen(),
      ),
      _NavItem(
        title: isTelecaller ? 'My Tasks' : 'Calling Tasks',
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
        screen: const CallingTasksScreen(),
      ),
      _NavItem(
        title: 'Callbacks',
        icon: Icons.event_available_outlined,
        activeIcon: Icons.event_available,
        screen: const CallbackScreen(),
      ),
      _NavItem(
        title: 'Call History',
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        screen: const CallHistoryScreen(),
      ),
    ];

    if (!isTelecaller) {
      navItems.add(
        _NavItem(
          title: 'Branches & Categories',
          icon: Icons.storefront_outlined,
          activeIcon: Icons.storefront,
          screen: const BranchManagementScreen(),
        ),
      );
      navItems.add(
        _NavItem(
          title: 'Employees',
          icon: Icons.badge_outlined,
          activeIcon: Icons.badge,
          screen: const EmployeeManagementScreen(),
        ),
      );
    }

    if (isSuperAdmin) {
      navItems.add(
        _NavItem(
          title: 'Companies',
          icon: Icons.business_outlined,
          activeIcon: Icons.business,
          screen: const CompanyDirectoryScreen(),
        ),
      );
    }

    if (_selectedIndex >= navItems.length) {
      _selectedIndex = 0;
    }

    final notifProvider = context.watch<NotificationProvider>();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: const NotificationDrawer(),
      body: Row(
        children: [
          // Desktop & Tablet Navigation Sidebar
          if (!isMobile)
            Container(
              width: 240,
              decoration: const BoxDecoration(
                color: AppColors.navBackground,
              ),
              child: Column(
                children: [
                  // Brand Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.accentViolet,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Telecaller CRM',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.navActive,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user?.companyName ?? (isSuperAdmin ? 'PLATFORM ADMIN' : 'WORKSPACE'),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.navActive, height: 1),
                  const SizedBox(height: 12),

                  // Menu Items
                  Expanded(
                    child: ListView.builder(
                      itemCount: navItems.length,
                      itemBuilder: (context, index) {
                        final item = navItems[index];
                        final isActive = _selectedIndex == index;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          child: InkWell(
                            onTap: () => setState(() => _selectedIndex = index),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.accentViolet : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isActive ? item.activeIcon : item.icon,
                                    size: 18,
                                    color: isActive ? Colors.white : Colors.white60,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    item.title,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                      color: isActive ? Colors.white : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // User Profile & Logout at Bottom
                  const Divider(color: AppColors.navActive, height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.accentViolet,
                          child: Text(
                            user?.firstName.isNotEmpty == true ? user!.firstName[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user?.fullName ?? '',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user?.role.replaceAll('_', ' ') ?? '',
                                style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, size: 18, color: Colors.white54),
                          tooltip: 'Logout',
                          onPressed: () => auth.logout(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top App Bar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (isMobile) ...[
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.navBackground,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.phone_in_talk, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            navItems[_selectedIndex].title,
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Notifications Bell with Badge
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined, size: 22),
                                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                              ),
                              if (notifProvider.unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 8, right: 8),
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text(
                                    '${notifProvider.unreadCount}',
                                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          ),
                          if (isMobile)
                            IconButton(
                              icon: const Icon(Icons.logout, size: 20),
                              onPressed: () => auth.logout(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Active View Body
                Expanded(
                  child: navItems[_selectedIndex].screen,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _selectedIndex >= navItems.length ? 0 : _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              selectedItemColor: AppColors.accentViolet,
              unselectedItemColor: AppColors.textSecondary,
              type: BottomNavigationBarType.fixed,
              backgroundColor: AppColors.surface,
              selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
              items: navItems.map((item) {
                return BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon),
                  label: item.title,
                );
              }).toList(),
            )
          : null,
    );
  }
}

class _NavItem {
  final String title;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;

  _NavItem({
    required this.title,
    required this.icon,
    required this.activeIcon,
    required this.screen,
  });
}
