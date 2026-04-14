import 'dart:convert';
import 'dart:typed_data';
import 'package:vosk_flutter/vosk_flutter.dart';
import 'package:record/record.dart';
import 'dart:async';

class WakeWordService {
  final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance(); // Corrected class name
  Model? _model;
  Recognizer? _recognizer;
  StreamSubscription? _audioSubscription;
  final AudioRecorder _recorder = AudioRecorder();
  
  final String wakeWord = "computer"; 
  final Function onWakeWordDetected;

  WakeWordService({required this.onWakeWordDetected});

  Future<void> init() async {
    print('🧩 [WakeWordService] Loading Vosk model...');
    try {
      final modelPath = await ModelLoader().loadFromAssets('assets/models/vosk-model-small-en-us.zip');
      print('🧩 [WakeWordService] Model loaded from assets at: $modelPath');
      
      _model = await _vosk.createModel(modelPath);
      
      _recognizer = await _vosk.createRecognizer(
        model: _model!,
        sampleRate: 16000,
        grammar: [wakeWord, "hey", "melo"],
      );
      print('✅ [WakeWordService] Recognizer initialized.');
    } catch (e) {
      print('❌ [WakeWordService] Initialization Error: $e');
    }
  }

  Future<void> start() async {
    if (_recognizer == null) {
      print('⚠️ [WakeWordService] Cannot start, recognizer is null.');
      return;
    }

    print('👂 [WakeWordService] Starting microphone stream for wake word...');
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));

    _audioSubscription = stream.listen((data) async {
      final uint8Data = Uint8List.fromList(data);
      // Corrected method name: acceptWaveformBytes
      final isFinal = await _recognizer!.acceptWaveformBytes(uint8Data);
      
      if (isFinal) {
        final result = jsonDecode(await _recognizer!.getResult());
        _checkResult(result['text'] as String? ?? "");
      } else {
        final partial = jsonDecode(await _recognizer!.getPartialResult());
        _checkResult(partial['partial'] as String? ?? "");
      }
    });
  }

  void _checkResult(String text) {
    if (text.isNotEmpty) {
      print('🔎 [WakeWordService] Partial/Result: "$text"');
    }
    
    if (text.contains(wakeWord) || text.contains("melo")) {
      print('🎉 [WakeWordService] WAKE WORD DETECTED!');
      onWakeWordDetected();
    }
  }

  Future<void> stop() async {
    await _audioSubscription?.cancel();
    await _recorder.stop();
  }
}
