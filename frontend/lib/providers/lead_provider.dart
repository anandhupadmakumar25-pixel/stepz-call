import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/lead_model.dart';

class LeadProvider extends ChangeNotifier {
  List<LeadModel> _leads = [];
  LeadModel? _selectedLead;
  bool _isLoading = false;
  String? _errorMessage;

  List<BranchModel> _branches = [];
  List<LeadCategoryModel> _categories = [];
  List<CallingTaskModel> _tasks = [];
  CallingTaskModel? _selectedTask;
  List<LeadModel> _taskLeads = [];

  ImportBatchModel? _activeImportBatch;
  bool _isImporting = false;

  List<LeadModel> get leads => _leads;
  LeadModel? get selectedLead => _selectedLead;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<BranchModel> get branches => _branches;
  List<LeadCategoryModel> get categories => _categories;
  List<CallingTaskModel> get tasks => _tasks;
  CallingTaskModel? get selectedTask => _selectedTask;
  CallingTaskModel? get activeTaskDetail => _selectedTask;
  bool get isLoadingTaskDetail => _isLoading;
  int get totalCount => _leads.length;
  List<LeadModel> get taskLeads => _taskLeads;
  ImportBatchModel? get activeImportBatch => _activeImportBatch;
  bool get isImporting => _isImporting;

  Future<void> fetchBranches() async {
    try {
      final res = await ApiClient.get('/leads/branches/');
      if (res is List) {
        _branches = res.map((item) => BranchModel.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> createBranch({
    required String name,
    String code = '',
    String address = '',
    double? latitude,
    double? longitude,
    int radiusMeters = 100,
    bool geofenceEnabled = true,
  }) async {
    try {
      final res = await ApiClient.post('/leads/branches/', {
        'name': name.trim(),
        'code': code.trim(),
        'address': address.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'geofence_enabled': geofenceEnabled,
      });
      final b = BranchModel.fromJson(res);
      _branches.add(b);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBranch({
    required String branchId,
    String? name,
    String? code,
    String? address,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    bool? geofenceEnabled,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (name != null) payload['name'] = name.trim();
      if (code != null) payload['code'] = code.trim();
      if (address != null) payload['address'] = address.trim();
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;
      if (radiusMeters != null) payload['radius_meters'] = radiusMeters;
      if (geofenceEnabled != null) payload['geofence_enabled'] = geofenceEnabled;

      final res = await ApiClient.patch('/leads/branches/$branchId/', payload);
      final updated = BranchModel.fromJson(res);
      final idx = _branches.indexWhere((b) => b.id == branchId);
      if (idx != -1) {
        _branches[idx] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBranch(String branchId) async {
    try {
      await ApiClient.delete('/leads/branches/$branchId/');
      _branches.removeWhere((b) => b.id == branchId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> fetchCategories() async {
    try {
      final res = await ApiClient.get('/leads/categories/');
      if (res is List) {
        _categories = res.map((item) => LeadCategoryModel.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> createCategory({required String name, String? colorCode, String? color, String description = ''}) async {
    try {
      final code = colorCode ?? color ?? '#6366F1';
      final res = await ApiClient.post('/leads/categories/', {
        'name': name.trim(),
        'color_code': code.trim(),
        'description': description.trim(),
      });
      final c = LeadCategoryModel.fromJson(res);
      _categories.add(c);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    try {
      await ApiClient.delete('/leads/categories/$categoryId/');
      _categories.removeWhere((c) => c.id == categoryId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> fetchLeads({String? status, String? search, String? branchId, String? categoryId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String query = '';
      final params = <String>[];
      if (status != null && status.isNotEmpty && status != 'ALL') {
        params.add('status=$status');
      }
      if (branchId != null && branchId.isNotEmpty && branchId != 'ALL') {
        params.add('branch=$branchId');
      }
      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'ALL') {
        params.add('category=$categoryId');
      }
      if (search != null && search.isNotEmpty) {
        params.add('search=${Uri.encodeComponent(search)}');
      }
      if (params.isNotEmpty) {
        query = '?${params.join('&')}';
      }

      final res = await ApiClient.get('/leads/$query');
      if (res is List) {
        _leads = res.map((item) => LeadModel.fromJson(item)).toList();
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

  Future<LeadModel?> fetchLeadDetail(String leadId) async {
    try {
      final res = await ApiClient.get('/leads/$leadId/');
      _selectedLead = LeadModel.fromJson(res);
      notifyListeners();
      return _selectedLead;
    } catch (_) {
      return null;
    }
  }

  Future<bool> createLead(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/leads/', data);
      final newLead = LeadModel.fromJson(res);
      _leads.insert(0, newLead);
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

  Future<ImportBatchModel?> uploadImportFile(List<int> bytes, String filename) async {
    _isImporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.uploadFile('/leads/import/upload/', bytes, filename);
      _activeImportBatch = ImportBatchModel.fromJson(res);
      _isImporting = false;
      notifyListeners();
      return _activeImportBatch;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isImporting = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      _isImporting = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> confirmImport(String batchId, {String? branchId, String? categoryId}) async {
    _isImporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final body = <String, dynamic>{};
      if (branchId != null && branchId.isNotEmpty) body['branch_id'] = branchId;
      if (categoryId != null && categoryId.isNotEmpty) body['category_id'] = categoryId;
      await ApiClient.post('/leads/import/confirm/$batchId/', body);
      _isImporting = false;
      _activeImportBatch = null;
      await fetchLeads();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isImporting = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isImporting = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> bulkAssign(List<String> leadIds, List<Map<String, dynamic>> allocations, String method) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/leads/bulk-assign/', {
        'lead_ids': leadIds,
        'allocations': allocations,
        'method': method,
      });
      await fetchLeads();
      _isLoading = false;
      notifyListeners();
      return res;
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

  Future<void> fetchTasks({String? branchId, String? categoryId, String? assignedToId, String? status, String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String>[];
      if (branchId != null && branchId.isNotEmpty && branchId != 'ALL') {
        params.add('branch=$branchId');
      }
      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'ALL') {
        params.add('category=$categoryId');
      }
      if (assignedToId != null && assignedToId.isNotEmpty && assignedToId != 'ALL') {
        params.add('assigned_to=$assignedToId');
      }
      if (status != null && status.isNotEmpty && status != 'ALL') {
        params.add('status=$status');
      }
      if (search != null && search.isNotEmpty) {
        params.add('search=${Uri.encodeComponent(search)}');
      }

      String query = '';
      if (params.isNotEmpty) {
        query = '?${params.join('&')}';
      }

      final res = await ApiClient.get('/leads/tasks/$query');
      if (res is List) {
        _tasks = res.map((item) => CallingTaskModel.fromJson(item)).toList();
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

  Future<CallingTaskModel?> fetchTaskDetail(String taskId) async {
    try {
      final res = await ApiClient.get('/leads/tasks/$taskId/');
      _selectedTask = CallingTaskModel.fromJson(res);
      if (res['leads'] is List) {
        _taskLeads = (res['leads'] as List).map((l) => LeadModel.fromJson(l)).toList();
      }
      notifyListeners();
      return _selectedTask;
    } catch (_) {
      return null;
    }
  }

  Future<bool> createTask({
    String? title,
    String description = '',
    String priority = 'MEDIUM',
    String? branchId,
    String? categoryId,
    String? assignedToId,
    String? dueDate,
    List<String> leadIds = const [],
    Map<String, dynamic>? data,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = data ?? {
        if (title != null) 'title': title,
        'description': description,
        'priority': priority,
        if (branchId != null) 'branch_id': branchId,
        if (branchId != null) 'branch': branchId,
        if (categoryId != null) 'category_id': categoryId,
        if (categoryId != null) 'category': categoryId,
        if (assignedToId != null) 'assigned_to_id': assignedToId,
        if (assignedToId != null) 'assigned_to': assignedToId,
        if (dueDate != null) 'due_date': dueDate,
        'lead_ids': leadIds,
      };
      final res = await ApiClient.post('/leads/tasks/', payload);
      final task = CallingTaskModel.fromJson(res);
      _tasks.insert(0, task);
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

  Future<bool> updateTaskStatus(String taskId, String status) async {
    try {
      final res = await ApiClient.patch('/leads/tasks/$taskId/', {'status': status});
      final updated = CallingTaskModel.fromJson(res);
      final idx = _tasks.indexWhere((t) => t.id == taskId);
      if (idx != -1) {
        _tasks[idx] = updated;
      }
      if (_selectedTask?.id == taskId) {
        _selectedTask = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask(String taskId) async {
    try {
      await ApiClient.delete('/leads/tasks/$taskId/');
      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateLeadNote(String leadId, String note) async {
    try {
      final res = await ApiClient.patch('/leads/$leadId/', {'notes': note});
      final updated = LeadModel.fromJson(res);
      final taskIdx = _taskLeads.indexWhere((l) => l.id == leadId);
      if (taskIdx != -1) {
        _taskLeads[taskIdx] = updated;
      }
      final leadIdx = _leads.indexWhere((l) => l.id == leadId);
      if (leadIdx != -1) {
        _leads[leadIdx] = updated;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<LeadModel?> updateLead(String leadId, Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.patch('/leads/$leadId/', data);
      final updated = LeadModel.fromJson(res);
      final taskIdx = _taskLeads.indexWhere((l) => l.id == leadId);
      if (taskIdx != -1) {
        _taskLeads[taskIdx] = updated;
      }
      final leadIdx = _leads.indexWhere((l) => l.id == leadId);
      if (leadIdx != -1) {
        _leads[leadIdx] = updated;
      }
      if (_selectedLead?.id == leadId) {
        _selectedLead = updated;
      }
      _isLoading = false;
      notifyListeners();
      return updated;
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

  Future<bool> updateLeadStatus(String leadId, String status) async {
    try {
      final res = await ApiClient.patch('/leads/$leadId/', {'status': status});
      final updated = LeadModel.fromJson(res);
      final taskIdx = _taskLeads.indexWhere((l) => l.id == leadId);
      if (taskIdx != -1) {
        _taskLeads[taskIdx] = updated;
      }
      final leadIdx = _leads.indexWhere((l) => l.id == leadId);
      if (leadIdx != -1) {
        _leads[leadIdx] = updated;
      }
      if (_selectedTask != null) {
        await fetchTaskDetail(_selectedTask!.id);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> scheduleLeadCallback(String leadId, DateTime scheduledAt, String note) async {
    try {
      await ApiClient.post('/callbacks/', {
        'lead': leadId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'initial_notes': note,
      });
      await updateLeadStatus(leadId, 'CALLBACK_REQUESTED');
      if (note.isNotEmpty) {
        await updateLeadNote(leadId, 'Callback scheduled: $note');
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rescheduleLeadCallback(String leadId, String scheduledAtIso, String note) async {
    try {
      final dt = DateTime.tryParse(scheduledAtIso) ?? DateTime.now().add(const Duration(days: 1));
      return await scheduleLeadCallback(leadId, dt, note);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
