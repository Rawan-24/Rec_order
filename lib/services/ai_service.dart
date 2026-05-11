import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AIService {
  // ── Change this to match where bridge.py is running ──────────────────────
  // Android emulator  → http://10.0.2.2:8080
  // Real device       → http://192.168.x.x:8080  (your PC's WiFi IP)-
  // iOS simulator     → http://localhost:8080
  // Web               → http://localhost:8080
  static const String _base = 'http://10.0.2.2:8080';

  static Future<Map<String, dynamic>> sendMessage(
      String text, {
        String sender = 'user1',
      }) async {
    try {
      final res = await http
          .post(
        Uri.parse('$_base/ask'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'sender': sender}),
      )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final replies = body['replies'] as List<dynamic>? ?? [];

        if (replies.isNotEmpty) {
          // Spread the full reply so extra fields like icon_type pass through
          final reply = Map<String, dynamic>.from(replies[0] as Map);
          debugPrint('FULL REPLY: $reply');        // ← add this
          debugPrint('FULL BODY: $body');          // ← add this
          return {
            ...reply,
            // Normalise: text-only replies like {"text":"sign_in"} become
            // {"command":"sign_in"} so every screen reads response['command']
            'command': body['intent'] ?? reply['command'] ?? reply['text'] ?? 'unknown', // ← body['intent'] first
            'value':   reply['value']   ?? '',
            'intent':  body['intent']   ?? 'unknown',
            'lang':    body['lang']     ?? 'en',
          };
        }
      }

      debugPrint('AIService: bad status ${res.statusCode}');
      return {'command': 'unknown', 'value': ''};
    } on Exception catch (e) {
      debugPrint('AIService error: $e');
      return {'command': 'unknown', 'value': ''};
    }
  }
}