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
        String? screen,
      }) async {
    try {
      final payload = {
        'text': text,
        'sender': sender,
        if (screen != null && screen.trim().isNotEmpty) 'screen': screen.trim(),
      };

      final res = await http
          .post(
        Uri.parse('$_base/ask'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final replies = body['replies'] as List<dynamic>? ?? [];

        if (replies.isNotEmpty) {
          final reply = Map<String, dynamic>.from(replies[0] as Map);

          debugPrint('FULL REPLY: $reply');
          debugPrint('FULL BODY: $body');

          String _clean(dynamic v) =>
              (v ?? '').toString().replaceAll(RegExp(r'[^a-z_]'), '').trim();
          String _cleanValue(dynamic v) => (v ?? '')
              .toString()
              .replaceAll(RegExp(r'[{}\[\]"]'), '')
              .replaceAll(RegExp(r',\s*$'), '')
              .trim();
          final command = _clean(reply['command'])
              .isNotEmpty ? _clean(reply['command'])
              : _clean(body['intent']).isNotEmpty ? _clean(body['intent'])
              : _clean(reply['text']).isNotEmpty ? _clean(reply['text'])
              : 'unknown';

          return {
            ...reply,
            'command': command,
            'text': _clean(reply['text']),
            'value': _cleanValue(reply['value']),
            'intent': _clean(body['intent']),
            'confidence': body['confidence'] ?? 0.0,
            'lang': body['lang'] ?? 'en',
          };
        }
      }

      debugPrint('AIService: bad status ${res.statusCode}');
      return {'command': 'unknown', 'value': '', 'intent': 'unknown'};
    } on Exception catch (e) {
      debugPrint('AIService error: $e');
      return {'command': 'unknown', 'value': '', 'intent': 'unknown'};
    }
  }

}