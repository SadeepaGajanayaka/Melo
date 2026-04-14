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
    await _player.play(DeviceFileSource(path));
  }

  Future<void> stopPlayback() async {
    await _player.stop();
  }

  Stream<Amplitude> onAmplitudeChanged() {
    return _recorder.onAmplitudeChanged(const Duration(milliseconds: 100));
  }

  bool get isPlaying => _player.state == PlayerState.playing;
}

