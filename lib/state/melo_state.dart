import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../services/wake_word_service.dart';
import '../services/ai_service.dart';
import '../services/audio_service.dart';

final aiServiceProvider = Provider((ref) => AiService());
final audioServiceProvider = Provider((ref) => AudioService());

enum AppStatus { idle, recording, thinking, responding }

class MeloState {
  final AppStatus status;
  final String lastAiText;
  final List<Content> chatHistory;
  final String? errorMessage;

  MeloState({
    this.status = AppStatus.idle,
    this.lastAiText = '',
    this.chatHistory = const [],
    this.errorMessage,
  });

  MeloState copyWith({
    AppStatus? status,
    String? lastAiText,
    List<Content>? chatHistory,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MeloState(
      status: status ?? this.status,
      lastAiText: lastAiText ?? this.lastAiText,
      chatHistory: chatHistory != null ? List.from(chatHistory) : this.chatHistory,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MeloNotifier extends StateNotifier<MeloState> {
  final AiService _ai;
  final AudioService _audio;
  late final WakeWordService _wakeWord;
  StreamSubscription? _amplitudeSub;
  DateTime? _lastVoiceTime;
  final double _silenceThreshold = -40.0;
  final int _silenceDurationMs = 1500;

  MeloNotifier(this._ai, this._audio) : super(MeloState()) {
    _wakeWord = WakeWordService(onWakeWordDetected: () {
      if (state.status == AppStatus.idle) {
        startTalking();
      }
    });
    _initWakeWord();
  }

  Future<void> _initWakeWord() async {
    await _wakeWord.init();
    await _wakeWord.start();
  }

  Future<void> startTalking() async {
    await _wakeWord.stop(); 
    state = state.copyWith(status: AppStatus.recording);
    await _audio.startRecording();

    _lastVoiceTime = DateTime.now();

    _amplitudeSub = _audio.onAmplitudeChanged().listen((amp) {
      if (amp.current > _silenceThreshold) {
        _lastVoiceTime = DateTime.now();
      } else {
        if (_lastVoiceTime != null) {
          final silenceDuration = DateTime.now().difference(_lastVoiceTime!).inMilliseconds;
          if (silenceDuration > _silenceDurationMs) {
            stopTalkingAndProcess();
          }
        }
      }
    });
  }

  Future<void> stopTalkingAndProcess() async {
    if (state.status != AppStatus.recording) return;
    
    await _amplitudeSub?.cancel();
    state = state.copyWith(status: AppStatus.thinking);
    
    final voicePath = await _audio.stopRecording();
    if (voicePath == null) {
      state = state.copyWith(status: AppStatus.idle);
      await _wakeWord.start();
      return;
    }

    try {
      final aiText = await _ai.getGeminiResponseFromVoice(
        voicePath, 
        state.chatHistory
      );
      
      final directory = await getTemporaryDirectory(); // Fixed: getTemporaryDirectory instead of getApplicationTemporaryDirectory
      final aiVoicePath = '${directory.path}/ai_resp.mp3';
      await _ai.textToSpeech(aiText, aiVoicePath);

      state = state.copyWith(
        status: AppStatus.responding,
        lastAiText: aiText,
        chatHistory: [
          ...state.chatHistory,
          Content('user', [TextPart("User voice command processed")]), // Fixed: Content constructor
          Content('model', [TextPart(aiText)]), // Fixed: Content constructor
        ],
      );

      await _audio.playAudio(aiVoicePath);
      
      Future.delayed(const Duration(seconds: 2), () async {
        state = state.copyWith(status: AppStatus.idle);
        await _wakeWord.start(); 
      });
      
    } catch (e) {
      debugPrint('🚨 [MeloNotifier] Fatal Error: $e');
      state = state.copyWith(
        status: AppStatus.idle,
        errorMessage: e.toString(),
      );
      await _wakeWord.start();
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final meloProvider = StateNotifierProvider<MeloNotifier, MeloState>((ref) {
  return MeloNotifier(
    ref.watch(aiServiceProvider),
    ref.watch(audioServiceProvider),
  );
});
