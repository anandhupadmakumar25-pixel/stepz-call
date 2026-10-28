import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telecaller_crm/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders login screen with title and input fields', (WidgetTester tester) async {
    await tester.pumpWidget(const TelecallerCrmApp());
    // Allow initial async auth initialization to complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Telecaller CRM branding is displayed
    expect(find.text('Telecaller CRM'), findsOneWidget);
    expect(find.text('Sign In to Workspace'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Verify Demo credential buttons
    expect(find.text('Company Admin'), findsOneWidget);
    expect(find.text('Telecaller'), findsOneWidget);
    expect(find.text('Super Admin'), findsOneWidget);
  });
}
