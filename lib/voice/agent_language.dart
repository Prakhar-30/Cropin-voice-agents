/// Languages supported by the offline voice agents.
enum AgentLanguage {
  english('en', 'English', 'EN', 'en_IN', 'en-IN'),
  hindi('hi', 'हिन्दी', 'HI', 'hi_IN', 'hi-IN'),
  kannada('kn', 'ಕನ್ನಡ', 'KN', 'kn_IN', 'kn-IN'),
  tamil('ta', 'தமிழ்', 'TA', 'ta_IN', 'ta-IN');

  const AgentLanguage(this.code, this.nativeName, this.short, this.sttLocale, this.ttsLocale);

  final String code;
  final String nativeName;
  final String short;

  /// Locale id passed to the on-device speech recogniser.
  final String sttLocale;

  /// Locale passed to the on-device TTS engine.
  final String ttsLocale;

  String get englishName => switch (this) {
        english => 'English',
        hindi => 'Hindi',
        kannada => 'Kannada',
        tamil => 'Tamil',
      };
}
