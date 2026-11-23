import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telecaller_crm/core/services/push_notification_service.dart';
import 'package:telecaller_crm/core/widgets/stepz_punch_widget.dart';
import 'package:telecaller_crm/models/attendance_model.dart';
import 'package:telecaller_crm/models/user_model.dart';
import 'package:telecaller_crm/providers/attendance_provider.dart';
import 'package:telecaller_crm/providers/auth_provider.dart';
import 'package:telecaller_crm/providers/lead_provider.dart';
import 'package:telecaller_crm/providers/notification_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserModel RBAC & Menu Permission Logic', () {
    test('Employee respects resolved_permissions and active_delegations', () {
      final emp = UserModel.fromJson({
        'id': 'u1',
        'email': 'emp@alpha.com',
        'first_name': 'Emp',
        'last_name': 'One',
        'full_name': 'Emp One',
        'role': 'EMPLOYEE',
        'company_allowed_menus': ['leads', 'attendance', 'quotations'],
        'resolved_permissions': ['leads.view_own', 'attendance.mark_own'],
        'active_delegations': [
          {
            'id': 'd1',
            'title': 'Acting HR',
            'delegator_id': 'a1',
            'delegator_name': 'Admin',
            'sections': ['employees'],
            'permissions': ['employees.view'],
            'start_date': '2026-11-01',
            'end_date': '2026-12-01',
          }
        ],
      });

      expect(emp.hasPermission('attendance.mark_own'), isTrue);
      expect(emp.hasPermission('leads.create'), isFalse);
      expect(emp.hasAnyPermission(['attendance.mark_own', 'attendance.punch']), isTrue);
      expect(emp.isDelegatedFor('employees'), isTrue);
      expect(emp.hasMenuPermission('leads'), isTrue);
      expect(emp.hasMenuPermission('billing'), isFalse);
    });

    test('Company Admin bypasses employee permission restrictions within allowed menus', () {
      final admin = UserModel.fromJson({
        'id': 'a1',
        'email': 'admin@alpha.com',
        'first_name': 'Admin',
        'last_name': 'Alpha',
        'full_name': 'Admin Alpha',
        'role': 'COMPANY_ADMIN',
        'company_allowed_menus': ['leads', 'attendance', 'billing'],
      });

      expect(admin.hasPermission('attendance.view_team'), isTrue);
      expect(admin.hasPermission('leads.create'), isTrue);
      expect(admin.hasMenuPermission('billing'), isTrue);
    });
  });

  group('AttendanceModel Parsing', () {
    test('Parses multi-session check-in, check-out, hours, and checkout reason notes', () {
      final rec = AttendanceModel.fromJson({
        'id': 'att1',
        'user': 'u1',
        'user_name': 'Emp One',
        'date': '2026-11-23',
        'tracking_mode': 'OFFICE',
        'check_in_time': '2026-11-23T09:15:00Z',
        'check_out_time': '2026-11-23T13:00:00Z',
        'working_hours': 3.75,
        'status': 'PRESENT',
        'notes': 'Client site visit',
      });

      expect(rec.checkInTime, isNotNull);
      expect(rec.checkOutTime, isNotNull);
      expect(rec.workingHours, 3.75);
      expect(rec.notes, 'Client site visit');
    });
  });

  group('StepzPunchWidget UI', () {
    testWidgets('Renders Check In button cleanly when not checked in', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => AttendanceProvider()),
            ChangeNotifierProvider(create: (_) => LeadProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StepzPunchWidget(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(StepzPunchWidget), findsOneWidget);
      expect(find.textContaining('Check In'), findsWidgets);
    });
  });

  group('Notification Deep-Link & Model Logic', () {
    test('Maps notification types and entity types to target screens', () {
      expect(PushNotificationService.resolveRouteKey('CALLBACK_REMINDER', 'callback'), 'callbacks');
      expect(PushNotificationService.resolveRouteKey('LEAD_ASSIGNED', 'lead'), 'leads');
      expect(PushNotificationService.resolveRouteKey('SYSTEM', 'invoice'), 'billing');
      expect(PushNotificationService.resolveRouteKey('SYSTEM', 'attendance'), 'attendance');
    });

    test('Parses NotificationItem entityType and entityId', () {
      final n = NotificationItem.fromJson({
        'id': 'n1',
        'title': 'Callback Due',
        'message': 'Call Lead',
        'notification_type': 'CALLBACK_REMINDER',
        'entity_type': 'callback',
        'entity_id': 'cb-1',
        'is_read': false,
        'created_at': '2026-11-23T10:00:00Z',
      });
      expect(n.entityType, 'callback');
      expect(n.entityId, 'cb-1');
      expect(n.isRead, isFalse);
    });
  });
}
