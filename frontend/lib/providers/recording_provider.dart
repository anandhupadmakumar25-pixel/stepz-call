import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/network/api_client.dart';
import '../models/recording_model.dart';

class RecordingProvider extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.telecaller.crm/call_recorder');

  List<CallRecordingModel> _recordings = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Live Recording State
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordingSeconds = 0;
  Timer? _timer;

  // Active recording metadata & captured audio buffer
  String? _activeLeadId;
  String? _activeLeadName;
  String? _activeLeadPhone;
  String? _activeCallAttemptId;
  Uint8List? _capturedAudioBytes;
  String? _capturedFileName;
  String _capturedSource = 'MIC_RECORDING';

  List<CallRecordingModel> get recordings => _recordings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  int get recordingSeconds => _recordingSeconds;
  int get elapsedSeconds => _recordingSeconds;
  bool get hasCapturedAudio => _capturedAudioBytes != null && _capturedAudioBytes!.isNotEmpty;
  bool get hasPendingRecording => hasCapturedAudio || _recordingSeconds > 0;
  String get capturedSource => _capturedSource;
  String? get capturedFileName => _capturedFileName;
  String get captureModeLabel {
    if (_capturedSource == 'SYSTEM_CALL_RECORDER') {
      return '2-Way System Call Recorder (Headset + Client)';
    }
    if (_capturedSource == 'AUTHORIZED_UPLOAD') {
      return 'Authorized Audio File Upload';
    }
    return 'Live Call Audio Capture (Headset + Mic)';
  }

  String? get activeLeadId => _activeLeadId;
  String? get activeLeadName => _activeLeadName;
  String? get activeLeadPhone => _activeLeadPhone;
  String? get activeCallAttemptId => _activeCallAttemptId;

  String get timerString {
    final m = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> ensurePermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('ensurePermissions');
    } catch (_) {}
  }

  Future<void> fetchRecordings({String? leadId, String? callId, String? employeeId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String path = '/calls/recordings/';
      final params = <String>[];
      if (leadId != null) params.add('lead=$leadId');
      if (callId != null) params.add('call=$callId');
      if (employeeId != null) params.add('employee=$employeeId');
      if (params.isNotEmpty) path += '?${params.join('&')}';

      final res = await ApiClient.get(path);
      if (res is List) {
        _recordings = res.map((json) => CallRecordingModel.fromJson(json)).toList();
      } else if (res is Map && res['results'] is List) {
        _recordings = (res['results'] as List).map((json) => CallRecordingModel.fromJson(json)).toList();
      } else {
        _recordings = [];
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startRecording({
    String? leadId,
    String? leadName,
    String? leadPhone,
    String? callAttemptId,
  }) async {
    _isRecording = true;
    _isPaused = false;
    _recordingSeconds = 0;
    _activeLeadId = leadId;
    _activeLeadName = leadName;
    _activeLeadPhone = leadPhone;
    _activeCallAttemptId = callAttemptId;
    _capturedAudioBytes = null;
    _capturedFileName = null;
    _capturedSource = 'MIC_RECORDING';

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod('startCallRecording', {
          'phoneNumber': leadPhone ?? '',
        });
      } catch (_) {}
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isPaused) {
        _recordingSeconds++;
        notifyListeners();
      }
    });

    notifyListeners();
  }

  Future<void> pauseRecording() async {
    if (_isRecording) {
      _isPaused = true;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _channel.invokeMethod('pauseCallRecording');
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  Future<void> resumeRecording() async {
    if (_isRecording && _isPaused) {
      _isPaused = false;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _channel.invokeMethod('resumeCallRecording');
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  Future<void> stopRecording({String? phoneNumber}) async {
    _timer?.cancel();
    _timer = null;
    _isPaused = true;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        // Wait briefly so any OEM System Call Recorder finishes flushing the 2-way audio file
        await Future.delayed(const Duration(milliseconds: 500));
        final res = await _channel.invokeMethod('stopCallRecording', {
          'phoneNumber': phoneNumber ?? _activeLeadPhone ?? '',
        });
        if (res is Map) {
          final bytes = res['fileBytes'];
          if (bytes is Uint8List && bytes.isNotEmpty) {
            _capturedAudioBytes = bytes;
          }
          _capturedFileName = res['fileName']?.toString() ?? 'call_recording.m4a';
          _capturedSource = res['source']?.toString() ?? 'MIC_RECORDING';
          final nativeDur = int.tryParse(res['durationSeconds']?.toString() ?? '0') ?? 0;
          if (nativeDur > 0) {
            _recordingSeconds = nativeDur;
          }
        }
      } catch (_) {}
    }

    notifyListeners();
  }

  void attachUploadedFile({
    required Uint8List fileBytes,
    required String fileName,
    int? durationSeconds,
  }) {
    _capturedAudioBytes = fileBytes;
    _capturedFileName = fileName;
    _capturedSource = 'AUTHORIZED_UPLOAD';
    if (durationSeconds != null && durationSeconds > 0) {
      _recordingSeconds = durationSeconds;
    } else if (_recordingSeconds == 0) {
      _recordingSeconds = 30;
    }
    notifyListeners();
  }

  void discardRecording() {
    _timer?.cancel();
    _timer = null;
    _isRecording = false;
    _isPaused = false;
    _recordingSeconds = 0;
    _activeLeadId = null;
    _activeLeadName = null;
    _activeLeadPhone = null;
    _activeCallAttemptId = null;
    _capturedAudioBytes = null;
    _capturedFileName = null;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _channel.invokeMethod('discardCallRecording').catchError((_) {});
    }
    notifyListeners();
  }

  void cancelRecording() => discardRecording();

  Future<bool> saveRecording({
    String? title,
    String? leadId,
    String? callAttemptId,
    required String notes,
    int? durationSeconds,
    int? overrideDurationSeconds,
  }) async {
    final targetLeadId = leadId ?? _activeLeadId;
    if (targetLeadId == null || targetLeadId.isEmpty) {
      _errorMessage = 'No active lead associated with this recording.';
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // If recording is still running, stop and resolve the audio file first
      if (_isRecording && _capturedAudioBytes == null) {
        await stopRecording();
      }

      final requestedDuration = durationSeconds ?? overrideDurationSeconds;
      final effectiveDuration = (requestedDuration != null && requestedDuration > 0 && _recordingSeconds == 0)
          ? requestedDuration
          : (_recordingSeconds > 0 ? _recordingSeconds : 1);

      final fields = <String, String>{
        'lead_id': targetLeadId,
        'duration_seconds': effectiveDuration.toString(),
        'source': _capturedSource,
        'notes': notes,
      };
      final targetCallId = callAttemptId ?? _activeCallAttemptId;
      if (targetCallId != null && targetCallId.isNotEmpty) {
        fields['call_attempt_id'] = targetCallId;
      }

      final res = await ApiClient.uploadRecordingMultipart(
        '/calls/recordings/',
        fields: fields,
        fileBytes: _capturedAudioBytes,
        filename: _capturedFileName ?? 'call_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );

      if (res != null && res is Map<String, dynamic>) {
        final newRecording = CallRecordingModel.fromJson(res);
        _recordings.insert(0, newRecording);

        _timer?.cancel();
        _timer = null;
        _isRecording = false;
        _isPaused = false;
        _recordingSeconds = 0;
        _activeLeadId = null;
        _activeLeadName = null;
        _activeLeadPhone = null;
        _activeCallAttemptId = null;
        _capturedAudioBytes = null;
        _capturedFileName = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Failed to save recording to backend.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> deleteRecording(String recordingId) async {
    try {
      await ApiClient.delete('/calls/recordings/$recordingId/');
      _recordings.removeWhere((r) => r.id == recordingId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
    }
    return false;
  }

  // Native Audio Playback Helpers
  static Future<bool> playAudioUrl(String url) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final resolved = ApiClient.resolveMediaUrl(url) ?? url;
      final ok = await _channel.invokeMethod('playAudio', {'url': resolved});
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> pauseAudioPlayback() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('pauseAudio');
    } catch (_) {}
  }

  static Future<void> stopAudioPlayback() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('stopAudio');
    } catch (_) {}
  }

  static Future<void> seekAudioPlayback(double seconds) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('seekAudio', {'positionSeconds': seconds});
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getAudioPlaybackStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return {'isPlaying': false, 'positionSeconds': 0.0, 'durationSeconds': 0.0, 'url': ''};
    }
    try {
      final res = await _channel.invokeMethod('getAudioStatus');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {'isPlaying': false, 'positionSeconds': 0.0, 'durationSeconds': 0.0, 'url': ''};
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
