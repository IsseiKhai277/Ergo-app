import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Service for AI-powered resume skill extraction using Groq API (LLaMA 3).
///
/// HOW IT WORKS:
/// 1. Reads the Groq API key from the .env file (never hardcoded).
/// 2. Downloads the resume PDF bytes from its Firebase Storage URL.
/// 3. Extracts plain text from the PDF locally using syncfusion_flutter_pdf.
/// 4. Sends the extracted text to LLaMA-3 via Groq's free API.
/// 5. Parses and returns the list of skills.
///
/// ── SETUP ────────────────────────────────────────────────────────────────────
/// 1. Sign up for free at https://console.groq.com
/// 2. Create an API key and add it to your .env file:
///    GROQ_API_KEY=gsk_your_key_here
///
/// The .env file is already listed in .gitignore — it will NOT be pushed to Git.
/// ─────────────────────────────────────────────────────────────────────────────
class ResumeAIService {
  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  // LLaMA 3.1 8B — fast, free, excellent at structured data extraction
  static const String _groqModel = 'llama-3.1-8b-instant';

  /// Reads the Groq API key from the .env file.
  static String get _apiKey {
    final key = dotenv.env['GROQ_API_KEY'] ?? '';
    if (key.isEmpty || key.startsWith('gsk_your')) {
      throw Exception(
        'GROQ_API_KEY is not set. '
        'Open the .env file at the project root and add your key:\n'
        '  GROQ_API_KEY=gsk_your_key_here\n'
        'Get a free key at https://console.groq.com',
      );
    }
    return key;
  }

  /// Extracts skills from a resume at [resumeUrl] (Firebase Storage URL).
  ///
  /// Returns a deduplicated list of skill strings, or throws on failure.
  static Future<List<String>> extractSkills({
    required String resumeUrl,
  }) async {
    final apiKey = _apiKey;

    // 1. Download the resume bytes from Firebase Storage
    final bytes = await _downloadBytes(resumeUrl);
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Failed to download resume from Firebase Storage.');
    }

    // 2. Extract plain text from the PDF
    final resumeText = _extractTextFromPdf(bytes);
    if (resumeText.trim().isEmpty) {
      throw Exception(
        'Could not extract text from resume. '
        'The file may be image-based or corrupted.',
      );
    }

    debugPrint('[ResumeAIService] Extracted ${resumeText.length} chars from PDF.');

    // 3. Truncate to ~3000 chars to stay within token limits
    final truncatedText = resumeText.length > 3000
        ? resumeText.substring(0, 3000)
        : resumeText;

    // 4. Call Groq API (OpenAI-compatible format)
    final response = await http.post(
      Uri.parse(_groqEndpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _groqModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an expert HR assistant. When given a resume, you extract '
                'all professional and technical skills and return ONLY a valid JSON '
                'array of skill strings — no explanation, no markdown, just the array. '
                'Each skill should be concise (1–4 words), properly capitalised, and deduplicated. '
                'Example: ["Flutter", "Dart", "Firebase", "REST API", "UI/UX Design"]',
          },
          {
            'role': 'user',
            'content': 'Extract all skills from this resume:\n\n$truncatedText',
          },
        ],
        'temperature': 0.1,
        'max_tokens': 512,
      }),
    );

    debugPrint('[ResumeAIService] Groq status: ${response.statusCode}');
    debugPrint('[ResumeAIService] Groq response: ${response.body}');

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final message = body['error']?['message'] ?? response.body;
      throw Exception('Groq API error ${response.statusCode}: $message');
    }

    // 5. Parse the response
    final decoded = jsonDecode(response.body);
    final generatedText =
        decoded['choices']?[0]?['message']?['content'] ?? '';

    debugPrint('[ResumeAIService] Generated: $generatedText');

    return _parseSkills(generatedText);
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  /// Downloads raw bytes from a public URL.
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

  /// Extracts plain text from a PDF byte array using Syncfusion.
  static String _extractTextFromPdf(Uint8List bytes) {
    try {
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      return text;
    } catch (e) {
      debugPrint('[ResumeAIService] PDF text extraction error: $e');
      return '';
    }
  }

  /// Extracts a JSON array of strings from the model's response text.
  static List<String> _parseSkills(String text) {
    final cleaned = text
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

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
