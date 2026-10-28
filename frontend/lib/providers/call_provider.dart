import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/network/api_client.dart';
import '../models/call_model.dart';

class CallProvider extends ChangeNotifier {
  List<CallAttemptModel> _calls = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CallAttemptModel> get calls => _calls;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> launchDialer(String phoneNumber) async {
    try {
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-]'), '');
      final uri = Uri.parse('tel:$cleanNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      } else {
        // Direct launch fallback
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      _errorMessage = 'Could not launch phone dialer: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchCalls({String? leadId, String? employeeId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final params = <String>[];
      if (leadId != null) params.add('lead=$leadId');
      if (employeeId != null) params.add('employee=$employeeId');
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';

      final res = await ApiClient.get('/calls/$query');
      if (res is List) {
        _calls = res.map((c) => CallAttemptModel.fromJson(c)).toList();
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

  Future<bool> logCallOutcome({
    required String leadId,
    required String outcome,
    required String notes,
    int durationSeconds = 0,
    DateTime? dialerLaunchedAt,
    bool scheduleCallback = false,
    DateTime? callbackTime,
    String? callbackNotes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = {
        'lead_id': leadId,
        'outcome': outcome,
        'notes': notes,
        'duration_seconds': durationSeconds,
        'dialer_launched_at': dialerLaunchedAt?.toIso8601String(),
        'schedule_callback': scheduleCallback,
        'callback_time': callbackTime?.toIso8601String(),
        'callback_notes': callbackNotes,
      };

      final res = await ApiClient.post('/calls/', payload);
      final newCall = CallAttemptModel.fromJson(res);
      _calls.insert(0, newCall);

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
}
