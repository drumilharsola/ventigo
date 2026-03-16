/// Content moderation filter for social media names and offensive words in
/// English and Hindi. Used in chat messages and community board posts.
class ContentFilter {
  ContentFilter._();

  // Social media / contact info patterns
  static final _socialPatterns = RegExp(
    r'(?:instagram|insta|snapchat|snap|whatsapp|telegram|discord|tiktok|'
    r'twitter|facebook|fb|linkedin|youtube|yt|signal|wechat|line|kik|'
    r'@[a-zA-Z0-9_.]+|'                  // @username patterns
    r'\b\d{10,13}\b|'                      // phone numbers (10-13 digits)
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',  // email
    caseSensitive: false,
  );

  // English offensive words (partial list - add as needed)
  static const _enWords = <String>[
    'fuck', 'shit', 'bitch', 'asshole', 'bastard', 'dick', 'pussy',
    'cunt', 'damn', 'hell', 'slut', 'whore', 'nigger', 'nigga',
    'faggot', 'retard', 'crap', 'piss',
  ];

  // Hindi offensive words (transliterated - partial list)
  static const _hiWords = <String>[
    'madarchod', 'behenchod', 'chutiya', 'bhosdi', 'gaand', 'randi',
    'harami', 'lodu', 'bhosdike', 'lavde', 'gandu', 'chut', 'lund',
    'kamina', 'kutta', 'suar', 'haramkhor', 'bhenchod',
  ];

  static late final RegExp _badWordPattern = _buildBadWordPattern();

  static RegExp _buildBadWordPattern() {
    final allWords = [..._enWords, ..._hiWords];
    // Build pattern with word boundaries where possible
    final escaped = allWords.map((w) => RegExp.escape(w)).join('|');
    return RegExp('(?:$escaped)', caseSensitive: false);
  }

  /// Returns `true` if the text contains social media references or contact info.
  static bool hasSocialMedia(String text) => _socialPatterns.hasMatch(text);

  /// Returns `true` if the text contains offensive words.
  static bool hasBadWords(String text) => _badWordPattern.hasMatch(text);

  /// Returns `true` if the text violates any content policy.
  static bool isViolation(String text) =>
      hasSocialMedia(text) || hasBadWords(text);

  /// Replaces offensive content with asterisks while keeping social media
  /// references intact (those are blocked entirely, not masked).
  static String mask(String text) {
    return text.replaceAllMapped(_badWordPattern, (m) => '*' * m[0]!.length);
  }

  /// Returns a user-friendly error message if content violates policy, or
  /// `null` if the content is clean.
  static String? validate(String text) {
    if (hasSocialMedia(text)) {
      return 'Please don\'t share social media handles or contact info.';
    }
    if (hasBadWords(text)) {
      return 'Please keep the language respectful.';
    }
    return null;
  }
}
