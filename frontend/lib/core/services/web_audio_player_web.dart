// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

html.AudioElement? _audioElement;
String _currentUrl = '';

Future<bool> webPlayAudio(String url) async {
  try {
    _audioElement ??= html.AudioElement();
    if (_currentUrl != url) {
      _audioElement!.src = url;
      _currentUrl = url;
    }
    await _audioElement!.play();
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> webPauseAudio() async {
  try {
    _audioElement?.pause();
  } catch (_) {}
}

Future<void> webStopAudio() async {
  try {
    _audioElement?.pause();
    if (_audioElement != null) {
      _audioElement!.currentTime = 0;
    }
  } catch (_) {}
}

Future<void> webSeekAudio(double seconds) async {
  try {
    if (_audioElement != null) {
      _audioElement!.currentTime = seconds;
    }
  } catch (_) {}
}

Future<Map<String, dynamic>> webGetAudioStatus() async {
  final el = _audioElement;
  if (el == null) {
    return {'isPlaying': false, 'positionSeconds': 0.0, 'durationSeconds': 0.0, 'url': ''};
  }
  final dur = el.duration;
  final pos = el.currentTime;
  return {
    'isPlaying': !el.paused && !el.ended,
    'positionSeconds': pos.isNaN ? 0.0 : pos.toDouble(),
    'durationSeconds': dur.isNaN ? 0.0 : dur.toDouble(),
    'url': _currentUrl,
  };
}
