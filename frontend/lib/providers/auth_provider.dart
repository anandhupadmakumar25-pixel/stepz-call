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
        'email': email.trim(),
        'password': password,
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
      _errorMessage = 'Connection error. Please ensure backend is reachable.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
