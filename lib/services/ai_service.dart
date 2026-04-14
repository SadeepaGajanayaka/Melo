import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'tool_service.dart';

class AiService {
  late final GenerativeModel _model;
  final String _elevenLabsUrl = 'https://api.elevenlabs.io/v1';

  AiService() {
    final tools = [
      Tool(functionDeclarations: [
        FunctionDeclaration(
          'remember_detail',
          'Saves a fact or preference about the user for long-term memory.',
          Schema.object(
            properties: {
              'key': Schema.string(
                  description: 'The thing to remember (e.g., "favoriteColor")'),
              'value':
                  Schema.string(description: 'The specific detail to remember'),
            },
            requiredProperties: [
              'key',
              'value'
            ], // Fixed: changed from required to requiredProperties
          ),
        ),
        FunctionDeclaration(
          'getWeather',
          'Gets the current weather for a specific city.',
          Schema.object(
            properties: {
              'city': Schema.string(description: 'The name of the city'),
            },
            requiredProperties: ['city'], 
          ),
        ),
        FunctionDeclaration(
          'getCurrentTime',
          'Gets the current time and date.',
          Schema.object(properties: {}),
        ),
      ]),
    ];

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',//'gemini-2.5-flash-lite',
      apiKey: AppConstants.geminiApiKey,
      systemInstruction: Content.system(AppConstants.systemPrompt),
      tools: tools,
    );
  }

  Future<String> getGeminiResponseFromVoice(
      String audioFilePath, List<Content> history) async {
    debugPrint('🎙️ [AiService] Sending audio to Gemini: $audioFilePath');
    final audioFile = File(audioFilePath);
    final audioBytes = await audioFile.readAsBytes();

    final chat = _model.startChat(history: List<Content>.from(history));

    final content = Content.multi([
      TextPart("The user said this. Listen and handle any requests or tasks."),
      DataPart('audio/mp4', Uint8List.fromList(audioBytes)),
    ]);

    debugPrint('⏳ [AiService] Waiting for Gemini text response...');
    var response = await chat.sendMessage(content);
    
    while (response.functionCalls.isNotEmpty) {
      debugPrint('🛠️ [AiService] Handling tool calls...');
      final responses = <FunctionResponse>[];
      for (final call in response.functionCalls) {
        final result = await _executeTool(call);
        responses.add(FunctionResponse(call.name, result));
      }
      response = await chat.sendMessage(Content.functionResponses(responses));
    }

    debugPrint('✅ [AiService] Gemini responded successfully.');
    return response.text ?? "My bad bro, something went wrong.";
  }

  Future<Map<String, dynamic>> _executeTool(FunctionCall call) async {
    switch (call.name) {
      case 'remember_detail':
        final res = await ToolService.saveUserFact(
            call.args['key'] as String, call.args['value'] as String);
        return {'result': res};
      case 'getWeather':
        final res = await ToolService.getWeather(call.args['city'] as String);
        return {'result': res};
      case 'getCurrentTime':
        final res = ToolService.getCurrentTime();
        return {'result': res};
      default:
        return {'error': 'Tool not found'};
    }
  }

  Future<File> textToSpeech(String text, String outputPath) async {
    debugPrint('🗣️ [AiService] Requesting TTS from ElevenLabs for: "$text"');
    var response = await http.post(
      Uri.parse('$_elevenLabsUrl/text-to-speech/${AppConstants.voiceId}'),
      headers: {
        'Content-Type': 'application/json',
        'xi-api-key': AppConstants.elevenLabsApiKey,
      },
      body: jsonEncode({
        'text': text,
        'model_id': 'eleven_turbo_v2_5',
        'voice_settings': {'stability': 0.5, 'similarity_boost': 0.75}
      }),
    );

    if (response.statusCode == 200) {
      debugPrint('✅ [AiService] TTS file received successfully.');
      final file = File(outputPath);
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } else {
      final errorPrefix = 'ElevenLabs Error ${response.statusCode}: ';
      debugPrint('❌ [AiService] $errorPrefix ${response.body}');
      throw Exception('$errorPrefix ${response.body}');
    }
  }
}
