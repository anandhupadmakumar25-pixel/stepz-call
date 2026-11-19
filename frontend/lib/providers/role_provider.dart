import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/delegation_model.dart';
import '../models/role_model.dart';

class RoleProvider extends ChangeNotifier {
  List<RoleModel> _roles = [];
  List<PermissionGroupModel> _permissionCatalog = [];
  List<SectionDelegationModel> _delegations = [];
  List<PermissionAuditLogModel> _auditLogs = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<RoleModel> get roles => _roles;
  List<PermissionGroupModel> get permissionCatalog => _permissionCatalog;
  List<SectionDelegationModel> get delegations => _delegations;
  List<PermissionAuditLogModel> get auditLogs => _auditLogs;
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

  Future<void> fetchPermissionCatalog() async {
    try {
      final res = await ApiClient.get('/accounts/permissions/catalog/');
      if (res is Map<String, dynamic> && res['groups'] is List) {
        _permissionCatalog = (res['groups'] as List)
            .whereType<Map<String, dynamic>>()
            .map((g) => PermissionGroupModel.fromJson(g))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> fetchDelegations({String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final query = status != null && status.isNotEmpty ? '?status=$status' : '';
      final res = await ApiClient.get('/accounts/delegations/$query');
      if (res is List) {
        _delegations = res
            .whereType<Map<String, dynamic>>()
            .map((e) => SectionDelegationModel.fromJson(e))
            .toList();
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

  Future<SectionDelegationModel?> createDelegation({
    required String delegateeId,
    required String title,
    required List<String> sections,
    required List<String> permissions,
    required String startDate,
    required String endDate,
    String reason = '',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await ApiClient.post('/accounts/delegations/', {
        'delegatee': delegateeId,
        'title': title.trim(),
        'sections': sections,
        'permissions': permissions,
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason.trim(),
      });
      final created = SectionDelegationModel.fromJson(res as Map<String, dynamic>);
      _delegations.insert(0, created);
      _isLoading = false;
      notifyListeners();
      return created;
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

  Future<bool> revokeDelegation(String delegationId) async {
    try {
      final res = await ApiClient.post('/accounts/delegations/$delegationId/revoke/', {});
      final updated = SectionDelegationModel.fromJson(res as Map<String, dynamic>);
      final idx = _delegations.indexWhere((d) => d.id == delegationId);
      if (idx != -1) {
        _delegations[idx] = updated;
        notifyListeners();
      }
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchAuditLogs() async {
    try {
      final res = await ApiClient.get('/accounts/audit-logs/');
      if (res is List) {
        _auditLogs = res
            .whereType<Map<String, dynamic>>()
            .map((e) => PermissionAuditLogModel.fromJson(e))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
  }
}

