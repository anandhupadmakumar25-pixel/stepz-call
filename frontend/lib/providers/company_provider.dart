import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/company_model.dart';

class CompanyProvider extends ChangeNotifier {
  List<CompanyModel> _companies = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CompanyModel> get companies => _companies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  Future<bool> createCompany(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/companies/', data);
      final newComp = CompanyModel.fromJson(res);
      _companies.insert(0, newComp);
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

  Future<bool> updateCompanyStatus(String companyId, String newStatus) async {
    try {
      final res = await ApiClient.patch('/companies/$companyId/', {
        'status': newStatus,
      });
      final updated = CompanyModel.fromJson(res);
      final idx = _companies.indexWhere((c) => c.id == companyId);
      if (idx != -1) {
        _companies[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
