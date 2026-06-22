import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

/// Service for AI-powered resume skill extraction using the Gemini API.
///
/// HOW IT WORKS:
/// 1. Reads the Gemini API key from the .env file (never hardcoded in source).
/// 2. Downloads the resume PDF/DOCX bytes from its Firebase Storage URL.
/// 3. Sends the raw bytes to Gemini (gemini-1.5-flash) as an inline file part.
/// 4. Asks Gemini to extract skills and return a clean JSON array.
/// 5. Parses and returns the list of skills.
///
/// ── SETUP ────────────────────────────────────────────────────────────────────
/// 1. Open the .env file at the project root.
/// 2. Replace the placeholder with your key from Google AI Studio:
///    https://aistudio.google.com/app/apikey
///
///    GEMINI_API_KEY=your_actual_key_here
///
/// The .env file is already listed in .gitignore — it will NOT be pushed to Git.
/// ─────────────────────────────────────────────────────────────────────────────
class ResumeAIService {
  /// Reads the Gemini API key from the .env file loaded at app startup.
  static String get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.isEmpty || key == 'your_gemini_api_key_here') {
      throw Exception(
        'GEMINI_API_KEY is not set. '
        'Open the .env file at the project root and add your key:\n'
        '  GEMINI_API_KEY=your_actual_key_here\n'
        'Get a free key at https://aistudio.google.com/app/apikey',
      );
    }
    return key;
  }

  /// Extracts skills from a resume available at [resumeUrl] (Firebase Storage).
  ///
  /// Returns a deduplicated list of skill strings, or throws on failure.
  static Future<List<String>> extractSkills({required String resumeUrl}) async {
    // Throws a clear error if key is missing or still a placeholder
    final apiKey = _apiKey;

    // 1. Download the resume file bytes from Firebase Storage
    final bytes = await _downloadBytes(resumeUrl);
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Failed to download resume from Firebase Storage.');
    }

    // 2. Determine MIME type from URL extension
    final mimeType = resumeUrl.toLowerCase().contains('.docx')
        ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        : 'application/pdf';

    // 3. Call Gemini API with the file bytes
    final model = GenerativeModel(model: 'gemini-3.5-flash', apiKey: apiKey);

    const prompt = '''
You are an expert HR assistant. Analyse the provided resume document and extract 
all professional and technical skills mentioned. 

Return ONLY a valid JSON array of skill strings — nothing else.
Each skill should be concise (1–4 words), properly capitalised, and deduplicated.

Example output format:
["Flutter", "Dart", "Firebase", "REST API", "UI/UX Design", "Agile", "Git"]
''';

    final response = await model.generateContent([
      Content.multi([DataPart(mimeType, bytes), TextPart(prompt)]),
    ]);

    final text = response.text ?? '';
    debugPrint('[ResumeAIService] Raw Gemini response: $text');

    // 4. Parse the JSON array from the response
    return _parseSkills(text);
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Downloads raw bytes from a URL.
  static Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return response.bodyBytes;
      debugPrint(
        '[ResumeAIService] Download failed: HTTP ${response.statusCode}',
      );
      return null;
    } catch (e) {
      debugPrint('[ResumeAIService] Download error: $e');
      return null;
    }
  }

  /// Extracts a JSON array of strings from the Gemini response text.
  ///
  /// Handles cases where the model wraps the JSON in markdown code fences.
  static List<String> _parseSkills(String text) {
    // Strip markdown code fences if present
    final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();

    // Find the first [ ... ] array in the response
    final start = cleaned.indexOf('[');
    final end = cleaned.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) {
      debugPrint('[ResumeAIService] Could not find JSON array in response.');
      return [];
    }

    final jsonString = cleaned.substring(start, end + 1);

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('[ResumeAIService] JSON parse error: $e\nRaw: $jsonString');
    }

    return [];
  }
}
