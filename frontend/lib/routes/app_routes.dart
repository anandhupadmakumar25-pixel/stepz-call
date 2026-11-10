import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/layout/main_layout.dart';
import '../screens/leads/lead_detail_screen.dart';
import '../screens/tasks/create_calling_task_screen.dart';
import '../screens/tasks/task_detail_execution_screen.dart';
import '../screens/companies/company_detail_screen.dart';
import '../models/company_model.dart';

class AppRoutes {
  static const String root = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String leads = '/leads';
  static const String leadDetail = '/leads/detail';
  static const String tasks = '/tasks';
  static const String createTask = '/tasks/create';
  static const String taskExecution = '/tasks/execute';
  static const String callbacks = '/callbacks';
  static const String callHistory = '/calls/history';
  static const String callRecordings = '/calls/recordings';
  static const String employees = '/employees';
  static const String attendance = '/attendance';
  static const String branches = '/branches';
  static const String companies = '/companies';
  static const String companyDetail = '/companies/detail';
  static const String plans = '/plans';
  static const String billing = '/billing';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case root:
      case dashboard:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'dashboard'),
        );

      case login:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );

      case leads:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'leads'),
        );

      case leadDetail:
        final leadId = settings.arguments as String?;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LeadDetailScreen(leadId: leadId ?? ''),
        );

      case tasks:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'tasks'),
        );

      case createTask:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const CreateCallingTaskScreen(),
        );

      case taskExecution:
        final arg = settings.arguments;
        final taskId = arg is String ? arg : (arg != null ? (arg as dynamic).id?.toString() ?? '' : '');
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => TaskDetailExecutionScreen(taskId: taskId),
        );

      case callbacks:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'callbacks'),
        );

      case callHistory:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'call_history'),
        );

      case callRecordings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'recordings'),
        );

      case employees:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'employees'),
        );

      case attendance:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'attendance'),
        );

      case branches:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'branches'),
        );

      case companies:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'companies'),
        );

      case companyDetail:
        final compArg = settings.arguments;
        final company = compArg is CompanyModel ? compArg : null;
        final companyId = compArg is String ? compArg : (compArg is CompanyModel ? compArg.id : '');
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => CompanyDetailScreen(companyId: companyId, initialCompany: company),
        );

      case plans:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'plans'),
        );

      case billing:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'billing'),
        );

      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const MainLayout(initialRouteKey: 'dashboard'),
        );
    }
  }
}
