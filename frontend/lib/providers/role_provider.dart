import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/role_model.dart';

class RoleProvider extends ChangeNotifier {
  List<RoleModel> _roles = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<RoleModel> get roles => _roles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchRoles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.get('/accounts/roles/');
      if (res is List) {
        _roles = res.map((r) => RoleModel.fromJson(r as Map<String, dynamic>)).toList();
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

  Future<RoleModel?> createRole({
    required String name,
    String code = '',
    String description = '',
    List<String> permissions = const [],
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/accounts/roles/', {
        'name': name.trim(),
        'code': code.trim(),
        'description': description.trim(),
        'permissions': permissions,
      });
      final role = RoleModel.fromJson(res as Map<String, dynamic>);
      _roles.add(role);
      _isLoading = false;
      notifyListeners();
      return role;
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

  Future<bool> updateRole({
    required String roleId,
    String? name,
    String? code,
    String? description,
    List<String>? permissions,
    bool? isActive,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name.trim();
      if (code != null) payload['code'] = code.trim();
      if (description != null) payload['description'] = description.trim();
      if (permissions != null) payload['permissions'] = permissions;
      if (isActive != null) payload['is_active'] = isActive;

      final res = await ApiClient.patch('/accounts/roles/$roleId/', payload);
      final updated = RoleModel.fromJson(res as Map<String, dynamic>);
      final idx = _roles.indexWhere((r) => r.id == roleId);
      if (idx != -1) {
        _roles[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRole(String roleId) async {
    try {
      await ApiClient.delete('/accounts/roles/$roleId/');
      _roles.removeWhere((r) => r.id == roleId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}

