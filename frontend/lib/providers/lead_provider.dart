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

  ImportBatchModel? _activeImportBatch;
  bool _isImporting = false;

  List<LeadModel> get leads => _leads;
  LeadModel? get selectedLead => _selectedLead;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<BranchModel> get branches => _branches;
  List<LeadCategoryModel> get categories => _categories;
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

  Future<bool> createBranch({required String name, String code = '', String address = ''}) async {
    try {
      final res = await ApiClient.post('/leads/branches/', {
        'name': name.trim(),
        'code': code.trim(),
        'address': address.trim(),
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

  Future<bool> createCategory({required String name, String colorCode = '#6366F1', String description = ''}) async {
    try {
      final res = await ApiClient.post('/leads/categories/', {
        'name': name.trim(),
        'color_code': colorCode.trim(),
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
}
