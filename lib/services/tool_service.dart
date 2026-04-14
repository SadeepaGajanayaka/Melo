import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ToolService {
  // 1. Memory Tool: Store a fact about the user
  static Future<String> saveUserFact(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final facts = prefs.getString('user_facts') ?? '{}';
    Map<String, dynamic> factsMap = jsonDecode(facts);
    
    factsMap[key] = value;
    await prefs.setString('user_facts', jsonEncode(factsMap));
    
    return "Successfully remembered that $key is $value.";
  }

  // 2. Memory Tool: Get all remembered facts
  static Future<String> getAllFacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_facts') ?? 'I don\'t know much about you yet, bro.';
  }

  // 3. World Tool: Get current time/date
  static String getCurrentTime() {
    final now = DateTime.now();
    return "The current time is ${now.hour}:${now.minute} on ${now.day}/${now.month}/${now.year}.";
  }

  // 4. World Tool: Weather (Mock for now, easy to plug API)
  static Future<String> getWeather(String city) async {
    // In a real pro app, you'd use a weather API here
    return "It's currently 72°F and sunny in $city. Perfect vibe, bro.";
  }
}
