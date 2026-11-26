import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/utils/region_detector.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _errorCode;
  Map<String, dynamic>? _lastErrorData;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;
  Map<String, dynamic>? get lastErrorData => _lastErrorData;

  Future<void> initAuth() async {
    _isLoading = true;
    notifyListeners();
    try {
      final userMap = await ApiClient.getUser();
      final token = await ApiClient.getToken();
      if (token != null && token.isNotEmpty && userMap != null) {
        // Verify cached token & user against live backend (clears stale session after DB reset)
        final liveRes = await ApiClient.get('/accounts/profile/');
        if (liveRes is Map<String, dynamic>) {
          final freshToken = await ApiClient.getToken() ?? token;
          await ApiClient.saveSession(freshToken, '', liveRes);
          _currentUser = UserModel.fromJson(liveRes);
        } else {
          await ApiClient.clearSession();
          _currentUser = null;
        }
      }
    } on ApiException {
      await ApiClient.clearSession();
      _currentUser = null;
    } catch (_) {
      await ApiClient.clearSession();
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Silently refreshes the logged-in user's profile and resolved permissions
  /// from the backend so role/permission updates take effect without re-login.
  Future<void> refreshProfile() async {
    try {
      final token = await ApiClient.getToken();
      if (token == null || token.isEmpty) return;
      final liveRes = await ApiClient.get('/accounts/profile/');
      if (liveRes is Map<String, dynamic>) {
        final freshToken = await ApiClient.getToken() ?? token;
        await ApiClient.saveSession(freshToken, '', liveRes);
        _currentUser = UserModel.fromJson(liveRes);
        notifyListeners();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404) {
        await ApiClient.clearSession();
        _currentUser = null;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> login(String usernameOrEmail, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    _lastErrorData = null;
    notifyListeners();

    try {
      final cleanInput = usernameOrEmail.trim();
      final detectedCountryIso = await RegionDetector.detectCountryIsoWithLocation();
      final res = await ApiClient.post('/accounts/login/', {
        'email': cleanInput,
        'username': cleanInput,
        'password': password.trim(),
        if (detectedCountryIso != null) 'detected_country_iso': detectedCountryIso,
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
      _errorCode = e.data?['code']?.toString();
      _lastErrorData = e.data;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Connection error: ${e.toString()}';
      _errorCode = null;
      _lastErrorData = null;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final res = await ApiClient.post('/accounts/change-password/', {
        'old_password': oldPassword,
        'new_password': newPassword,
      });
      return {
        'success': true,
        'message': res['message'] ?? 'Password updated successfully.',
      };
    } on ApiException catch (e) {
      final detail = e.data?['error'] ??
          e.data?['detail'] ??
          (e.data?['old_password'] is List ? (e.data!['old_password'] as List).first : null) ??
          e.message;
      return {
        'success': false,
        'error': detail.toString(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
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
    String? countryCode,
    String? countryIso,
    String? currency,
    String? currencySymbol,
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
    if (countryCode != null) json['company_country_code'] = countryCode;
    if (countryIso != null) json['company_country_iso'] = countryIso;
    if (currency != null) json['company_currency'] = currency;
    if (currencySymbol != null) json['company_currency_symbol'] = currencySymbol;
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
    RegionDetector.clearCache();
    _currentUser = null;
    notifyListeners();
  }
}
