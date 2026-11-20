Future<bool> webPlayAudio(String url) async => false;
Future<void> webPauseAudio() async {}
Future<void> webStopAudio() async {}
Future<void> webSeekAudio(double seconds) async {}
Future<Map<String, dynamic>> webGetAudioStatus() async => {
      'isPlaying': false,
      'positionSeconds': 0.0,
      'durationSeconds': 0.0,
      'url': '',
    };

