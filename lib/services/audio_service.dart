import 'dart:async';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String? _lastRecordingPath;

  Future<void> startRecording() async {
    print('🎤 [AudioService] Checking microphone permissions...');
    if (await _recorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      _lastRecordingPath = '${directory.path}/my_voice.m4a';
      
      print('🎤 [AudioService] Starting recording to: $_lastRecordingPath');
      await _recorder.start(const RecordConfig(), path: _lastRecordingPath!);
    } else {
      print('❌ [AudioService] Permission denied for microphone!');
    }
  }

  Future<String?> stopRecording() async {
    print('🎤 [AudioService] Stopping recording...');
    final path = await _recorder.stop();
    print('🎤 [AudioService] Recording saved at: $path');
    return path;
  }

  Future<void> playAudio(String path) async {
    print('🔊 [AudioService] Playing audio from: $path');
    
    // Create a completer that resolves when playback finishes
    final completer = Completer<void>();
    
    // Listen for playback completion
    late final StreamSubscription sub;
    sub = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) {
        print('🔊 [AudioService] Playback completed.');
        completer.complete();
      }
      sub.cancel();
    });
    
    // Also handle unexpected state changes (e.g. errors or stops)
    late final StreamSubscription stateSub;
    stateSub = _player.onPlayerStateChanged.listen((playerState) {
      if (playerState == PlayerState.stopped && !completer.isCompleted) {
        print('🔊 [AudioService] Playback stopped unexpectedly.');
        completer.complete();
        stateSub.cancel();
      }
    });
    
    await _player.play(DeviceFileSource(path));
    
    // Wait until the audio actually finishes playing
    await completer.future;
    
    // Clean up listeners
    stateSub.cancel();
  }

  Future<void> stopPlayback() async {
    await _player.stop();
  }

  Stream<Amplitude> onAmplitudeChanged() {
    return _recorder.onAmplitudeChanged(const Duration(milliseconds: 100));
  }

  bool get isPlaying => _player.state == PlayerState.playing;
}

