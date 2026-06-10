/// Placeholder service for AI-powered resume skill extraction.
///
/// CURRENT BEHAVIOR: Returns mock/sample skills for demonstration.
/// The resume is already uploaded to Firebase Storage by [ProfileService].
///
/// FUTURE INTEGRATION:
/// TODO: Connect to an AI API (e.g., Gemini, OpenAI, LangChain agent)
/// TODO: Send resume text or URL to the AI service endpoint
/// TODO: Parse the AI response and return real skill suggestions
/// TODO: Handle rate limiting, errors, and token costs
///
/// Architecture is kept modular so AI agents can be wired in
/// without changing calling code in [ProfileScreen].
class ResumeAIService {
  // ─── Mock skill templates ──────────────────────────────────────────────────
  static const List<String> _mockSkillPool = [
    'Flutter',
    'Dart',
    'Firebase',
    'REST API',
    'UI/UX Design',
    'Project Management',
    'Communication',
    'Problem Solving',
    'Agile',
    'Git',
    'Python',
    'JavaScript',
    'SQL',
    'Data Analysis',
    'Machine Learning',
  ];

  /// Simulates AI skill extraction from a resume.
  ///
  /// [resumeUrl] — Firebase Storage URL of the uploaded resume (for future use).
  ///
  /// Returns a list of suggested skills (currently mock data).
  static Future<List<String>> extractSkills({
    required String resumeUrl,
  }) async {
    // TODO: Replace with actual AI API call:
    // 1. Download resume text from [resumeUrl] or send URL to AI service
    // 2. Call AI API with resume content
    // 3. Parse response for skill entities
    // 4. Return deduplicated, normalized skill list

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Return mock skills (randomized subset for demo variety)
    final mockSkills = List<String>.from(_mockSkillPool)..shuffle();
    return mockSkills.take(6).toList();
  }
}
