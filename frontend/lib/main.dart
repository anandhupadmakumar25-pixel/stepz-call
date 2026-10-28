import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/lead_provider.dart';
import 'providers/call_provider.dart';
import 'providers/callback_provider.dart';
import 'providers/employee_provider.dart';
import 'providers/company_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/layout/main_layout.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TelecallerCrmApp());
}

class TelecallerCrmApp extends StatelessWidget {
  const TelecallerCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initAuth()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => LeadProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
        ChangeNotifierProvider(create: (_) => CallbackProvider()),
        ChangeNotifierProvider(create: (_) => EmployeeProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(1440, 900),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return MaterialApp(
                title: 'Telecaller CRM SaaS',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                home: auth.isLoading
                    ? const Scaffold(
                        body: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : auth.isAuthenticated
                        ? const MainLayout()
                        : const LoginScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
