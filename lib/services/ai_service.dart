import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String rasaUrl =
      "http://10.0.2.2:5005/webhooks/rest/webhook";

  static Future<Map<String, dynamic>> sendMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse(rasaUrl),
        body: jsonEncode({
          "sender": "user",
          "message": message,
        }),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode != 200) {
        return {"text": null, "command": "error"};
      }

      final List<dynamic> data = jsonDecode(response.body);

      if (data.isEmpty) {
        return {"text": null, "command": "unknown"};
      }

      final item = data[0] as Map<String, dynamic>;

      // ─────────────────────────────────────────────────────────
      // FIX 1 & 2 & 3:
      // Rasa actions already return the exact command string
      // (e.g. "sign_in", "open_signup", "next", "select_english").
      // We were re-parsing with contains() which:
      //   - broke on underscore vs space ("sign_in" ≠ "sign in")
      //   - caused false matches ("sign_in" contains "en" → language_en!)
      //
      // Solution: treat the Rasa text response AS the command directly.
      // Rasa is the NLU + intent mapper — trust its output.
      // ─────────────────────────────────────────────────────────

      // FIX 3: Handle json_message responses (used by action_provide_phone).
      // When Rasa uses dispatcher.utter_message(json_message={...}),
      // the REST channel returns it in data[0]["custom"], NOT data[0]["text"].
      if (item.containsKey("custom")) {
        final custom = Map<String, dynamic>.from(item["custom"] as Map);
        print("AI CUSTOM RESPONSE: $custom");
        return custom; // Already contains "command" and "value"
      }

      // FIX 1 + 2: Use Rasa's text response as the command directly.
      // No more fragile contains() parsing.
      final String command = (item["text"] ?? "").toString().trim();
      print("AI COMMAND FROM RASA: $command");

      if (command.isEmpty) {
        return {"text": null, "command": "unknown"};
      }

      return {"text": command, "command": command};

    } catch (e) {
      print("AI ERROR: $e");
      return {"text": null, "command": "error"};
    }
  }
}