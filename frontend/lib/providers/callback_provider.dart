import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/callback_model.dart';

class CallbackProvider extends ChangeNotifier {
  List<CallbackModel> _callbacks = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CallbackModel> get callbacks => _callbacks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchCallbacks({String? status, String? dateFilter}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String>[];
      if (status != null && status.isNotEmpty && status != 'ALL') {
        params.add('status=$status');
      }
      if (dateFilter != null && dateFilter.isNotEmpty) {
        params.add('date_filter=$dateFilter');
      }
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';

      final res = await ApiClient.get('/callbacks/$query');
      if (res is List) {
        _callbacks = res.map((c) => CallbackModel.fromJson(c)).toList();
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

  Future<bool> rescheduleCallback(String callbackId, DateTime newTime, String reason) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/callbacks/$callbackId/reschedule/', {
        'new_scheduled_at': newTime.toIso8601String(),
        'reason': reason,
      });

      final updated = CallbackModel.fromJson(res);
      final index = _callbacks.indexWhere((c) => c.id == callbackId);
      if (index != -1) {
        _callbacks[index] = updated;
      }
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

  Future<bool> completeCallback(String callbackId, String completionNotes) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/callbacks/$callbackId/complete/', {
        'completion_notes': completionNotes,
      });

      final updated = CallbackModel.fromJson(res);
      final index = _callbacks.indexWhere((c) => c.id == callbackId);
      if (index != -1) {
        _callbacks[index] = updated;
      }
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

  Future<void> checkReminders() async {
    try {
      await ApiClient.post('/callbacks/check-reminders/', {});
      await fetchCallbacks();
    } catch (_) {}
  }
}
