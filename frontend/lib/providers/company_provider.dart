import '../models/company_policy_model.dart';
import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/company_model.dart';
import '../models/plan_model.dart';

class CompanyProvider extends ChangeNotifier {
  List<CompanyModel> _companies = [];
  List<PlanModel> _plans = [];
  Map<String, dynamic>? _billingOverview;
  CompanyModel? _activeCompanyDetail;
  bool _isLoading = false;
  String? _errorMessage;

  CompanyPayrollPolicyModel? _payrollPolicy;
  List<CompanyCustomRuleModel> _companyRules = [];
  bool _isLoadingPolicy = false;
  bool _isLoadingRules = false;

  CompanyPayrollPolicyModel? get payrollPolicy => _payrollPolicy;
  List<CompanyCustomRuleModel> get companyRules => _companyRules;
  bool get isLoadingPolicy => _isLoadingPolicy;
  bool get isLoadingRules => _isLoadingRules;

  List<CompanyModel> get companies => _companies;
  List<PlanModel> get plans => _plans;
  Map<String, dynamic>? get billingOverview => _billingOverview;
  CompanyModel? get activeCompanyDetail => _activeCompanyDetail;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setActiveCompany(CompanyModel? company) {
    _activeCompanyDetail = company;
    notifyListeners();
  }

  Future<CompanyModel?> fetchCompanyDetail(String companyId) async {
    try {
      final res = await ApiClient.get('/companies/$companyId/');
      if (res is Map<String, dynamic>) {
        final comp = CompanyModel.fromJson(res);
        _activeCompanyDetail = comp;
        final idx = _companies.indexWhere((c) => c.id == companyId);
        if (idx != -1) {
          _companies[idx] = comp;
        } else {
          _companies.add(comp);
        }
        notifyListeners();
        return comp;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    return _activeCompanyDetail;
  }

  Future<void> fetchCompanies() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.get('/companies/');
      if (res is List) {
        _companies = res.map((c) => CompanyModel.fromJson(c)).toList();
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPlans() async {
    try {
      final res = await ApiClient.get('/companies/plans/');
      if (res is List) {
        _plans = res.map((p) => PlanModel.fromJson(p)).toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<bool> createPlan(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/companies/plans/', data);
      final newPlan = PlanModel.fromJson(res);
      _plans.add(newPlan);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchBillingOverview() async {
    try {
      final res = await ApiClient.get('/companies/billing/overview/');
      if (res is Map<String, dynamic>) {
        _billingOverview = res;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  /// Creates a company and returns credential payload with temp_password
  Future<Map<String, dynamic>?> createCompanyWithCredentials(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/companies/', data);
      if (res is Map<String, dynamic>) {
        final compData = res['company'] ?? res;
        final newComp = CompanyModel.fromJson(compData);
        final existingIdx = _companies.indexWhere((c) => c.id == newComp.id);
        if (existingIdx != -1) {
          _companies[existingIdx] = newComp;
        } else {
          _companies.insert(0, newComp);
        }
        _isLoading = false;
        notifyListeners();
        // Refresh companies list from backend to get fresh counts
        fetchCompanies();
        return {
          'company': newComp,
          'admin_email': res['admin_email'] ?? newComp.contactEmail,
          'temp_password': res['temp_password'] ?? data['admin_password'] ?? '',
        };
      }
      _isLoading = false;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> createCompany(Map<String, dynamic> data) async {
    final result = await createCompanyWithCredentials(data);
    return result != null;
  }

  Future<bool> updateCompanyStatus(String companyId, String newStatus) async {
    try {
      final res = await ApiClient.patch('/companies/$companyId/', {
        'status': newStatus,
      });
      final updated = CompanyModel.fromJson(res);
      final idx = _companies.indexWhere((c) => c.id == companyId);
      if (idx != -1) {
        _companies[idx] = updated;
      }
      if (_activeCompanyDetail?.id == companyId) {
        _activeCompanyDetail = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCompanyPermissions(String companyId, List<String> allowedMenus, {String? planId}) async {
    try {
      final payload = <String, dynamic>{
        'allowed_menus': allowedMenus,
      };
      if (planId != null && planId.isNotEmpty) {
        payload['plan_id'] = planId;
      }
      final res = await ApiClient.patch('/companies/$companyId/permissions/', payload);
      if (res is Map<String, dynamic> && res['company'] != null) {
        final updated = CompanyModel.fromJson(res['company']);
        final idx = _companies.indexWhere((c) => c.id == companyId);
        if (idx != -1) {
          _companies[idx] = updated;
        }
        if (_activeCompanyDetail?.id == companyId) {
          _activeCompanyDetail = updated;
        }
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> resetCompanyAdminPassword(String companyId) async {
    try {
      final res = await ApiClient.post('/companies/$companyId/reset-password/', {});
      if (res is Map<String, dynamic>) {
        return res;
      }
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> fetchPayrollPolicy() async {
    _isLoadingPolicy = true;
    notifyListeners();
    try {
      final res = await ApiClient.get('/companies/payroll-policy/');
      if (res is Map<String, dynamic>) {
        _payrollPolicy = CompanyPayrollPolicyModel.fromJson(res);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingPolicy = false;
      notifyListeners();
    }
  }

  Future<bool> updatePayrollPolicy(Map<String, dynamic> payload) async {
    try {
      final res = await ApiClient.patch('/companies/payroll-policy/', payload);
      if (res is Map<String, dynamic>) {
        _payrollPolicy = CompanyPayrollPolicyModel.fromJson(res);
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
    return false;
  }

  Future<void> fetchCompanyRules() async {
    _isLoadingRules = true;
    notifyListeners();
    try {
      final res = await ApiClient.get('/companies/rules/');
      if (res is List) {
        _companyRules = res.map((r) => CompanyCustomRuleModel.fromJson(r as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingRules = false;
      notifyListeners();
    }
  }

  Future<bool> createCompanyRule(Map<String, dynamic> payload) async {
    try {
      final res = await ApiClient.post('/companies/rules/', payload);
      if (res is Map<String, dynamic>) {
        _companyRules.add(CompanyCustomRuleModel.fromJson(res));
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
    return false;
  }

  Future<bool> updateCompanyRule(String ruleId, Map<String, dynamic> payload) async {
    try {
      final res = await ApiClient.patch('/companies/rules/$ruleId/', payload);
      if (res is Map<String, dynamic>) {
        final updated = CompanyCustomRuleModel.fromJson(res);
        final idx = _companyRules.indexWhere((r) => r.id == ruleId);
        if (idx != -1) {
          _companyRules[idx] = updated;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
    return false;
  }

  Future<bool> deleteCompanyRule(String ruleId) async {
    try {
      await ApiClient.delete('/companies/rules/$ruleId/');
      _companyRules.removeWhere((r) => r.id == ruleId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
    return false;
  }

  Future<bool> loadRulePreset(String presetKey, {bool replaceExisting = false}) async {
    try {
      final res = await ApiClient.post('/companies/rules/preset/', {
        'preset_key': presetKey,
        'replace_existing': replaceExisting,
      });
      if (res is Map<String, dynamic>) {
        if (res['policy'] != null) {
          _payrollPolicy = CompanyPayrollPolicyModel.fromJson(res['policy']);
        }
        if (res['rules'] is List) {
          _companyRules = (res['rules'] as List)
              .map((r) => CompanyCustomRuleModel.fromJson(r as Map<String, dynamic>))
              .toList();
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
    return false;
  }
}
