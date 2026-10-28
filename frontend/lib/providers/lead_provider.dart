import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/lead_model.dart';

class LeadProvider extends ChangeNotifier {
  List<LeadModel> _leads = [];
  LeadModel? _selectedLead;
  bool _isLoading = false;
  String? _errorMessage;

  ImportBatchModel? _activeImportBatch;
  bool _isImporting = false;

  List<LeadModel> get leads => _leads;
  LeadModel? get selectedLead => _selectedLead;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ImportBatchModel? get activeImportBatch => _activeImportBatch;
  bool get isImporting => _isImporting;

  Future<void> fetchLeads({String? status, String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String query = '';
      final params = <String>[];
      if (status != null && status.isNotEmpty && status != 'ALL') {
        params.add('status=$status');
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

  Future<bool> confirmImport(String batchId) async {
    _isImporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiClient.post('/leads/import/confirm/$batchId/', {});
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
