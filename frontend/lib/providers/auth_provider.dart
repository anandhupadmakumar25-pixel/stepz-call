import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initAuth() async {
    _isLoading = true;
    notifyListeners();
    try {
      final userMap = await ApiClient.getUser();
      final token = await ApiClient.getToken();
      if (token != null && userMap != null) {
        _currentUser = UserModel.fromJson(userMap);
      }
    } catch (_) {
      await ApiClient.clearSession();
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/accounts/login/', {
        'email': email.trim().toLowerCase(),
        'password': password.trim(),
      });

      final accessToken = res['access'];
      final refreshToken = res['refresh'];
      final userMap = res['user'];

      await ApiClient.saveSession(accessToken, refreshToken, userMap);
      _currentUser = UserModel.fromJson(userMap);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void updateCurrentUserCompanyInfo({
    String? name,
    String? logo,
    String? phone,
    String? email,
    String? address,
    String? gstin,
    String? website,
  }) {
    if (_currentUser == null) return;
    final json = _currentUser!.toJson();
    if (name != null) json['company_name'] = name;
    if (logo != null) json['company_logo'] = logo;
    if (phone != null) json['company_phone'] = phone;
    if (email != null) json['company_email'] = email;
    if (address != null) json['company_address'] = address;
    if (gstin != null) json['company_gstin'] = gstin;
    if (website != null) json['company_website'] = website;
    _currentUser = UserModel.fromJson(json);
    notifyListeners();
  }

  Future<void> refreshUserProfile() async {
    try {
      final res = await ApiClient.get('/accounts/me/');
      if (res is Map<String, dynamic>) {
        _currentUser = UserModel.fromJson(res);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    try {
      await ApiClient.post('/accounts/logout/', {});
    } catch (_) {}
    await ApiClient.clearSession();
    _currentUser = null;
    notifyListeners();
  }
}
