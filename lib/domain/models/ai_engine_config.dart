enum AiProviderType {
  groqFree,
  geminiFree,
  openRouterFree,
  customOpenAi,
  offlineDemo,
}

extension AiProviderTypeMeta on AiProviderType {
  String get label {
    switch (this) {
      case AiProviderType.groqFree:
        return 'Groq Cloud (Free · Fastest < 0.5 s LPU — Recommended)';
      case AiProviderType.geminiFree:
        return 'Google Gemini AI Studio (Free · Fast Flash-Lite)';
      case AiProviderType.openRouterFree:
        return 'OpenRouter (:free · Fast multilingual gateway)';
      case AiProviderType.customOpenAi:
        return 'Custom / Local Ollama (OpenAI-compatible)';
      case AiProviderType.offlineDemo:
        return 'Local Contextual Engine (Offline · No API key)';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProviderType.groqFree:
        return 'llama-3.1-8b-instant';
      case AiProviderType.geminiFree:
        return 'gemini-3.5-flash-lite';
      case AiProviderType.openRouterFree:
        return 'meta-llama/llama-3.3-70b-instruct:free';
      case AiProviderType.customOpenAi:
        return 'llama3.2';
      case AiProviderType.offlineDemo:
        return 'local-contextual-v1';
    }
  }

  String get defaultBaseUrl {
    switch (this) {
      case AiProviderType.groqFree:
        return 'https://api.groq.com/openai/v1/chat/completions';
      case AiProviderType.geminiFree:
        return 'https://generativelanguage.googleapis.com/v1beta';
      case AiProviderType.openRouterFree:
        return 'https://openrouter.ai/api/v1/chat/completions';
      case AiProviderType.customOpenAi:
        return 'http://localhost:11434/v1/chat/completions';
      case AiProviderType.offlineDemo:
        return '';
    }
  }

  bool get requiresApiKey =>
      this == AiProviderType.groqFree ||
      this == AiProviderType.geminiFree ||
      this == AiProviderType.openRouterFree;
}

class SupportedLanguage {
  const SupportedLanguage({
    required this.code,
    required this.shortBadge,
    required this.localeId,
    required this.name,
    required this.englishName,
  });

  final String code;
  final String shortBadge;
  final String localeId;
  final String name;
  final String englishName;

  /// 24 verified BCP-47 languages supported across OS Speech Recognition,
  /// Whisper TTS synthesis, and multilingual LLM inference (Groq / Gemini / OpenRouter).
  static const List<SupportedLanguage> all = [
    SupportedLanguage(code: 'en', shortBadge: 'EN', localeId: 'en-US', name: 'English', englishName: 'English'),
    SupportedLanguage(code: 'es', shortBadge: 'ES', localeId: 'es-ES', name: 'Español', englishName: 'Spanish'),
    SupportedLanguage(code: 'fr', shortBadge: 'FR', localeId: 'fr-FR', name: 'Français', englishName: 'French'),
    SupportedLanguage(code: 'de', shortBadge: 'DE', localeId: 'de-DE', name: 'Deutsch', englishName: 'German'),
    SupportedLanguage(code: 'it', shortBadge: 'IT', localeId: 'it-IT', name: 'Italiano', englishName: 'Italian'),
    SupportedLanguage(code: 'pt', shortBadge: 'PT', localeId: 'pt-PT', name: 'Português', englishName: 'Portuguese'),
    SupportedLanguage(code: 'nl', shortBadge: 'NL', localeId: 'nl-NL', name: 'Nederlands', englishName: 'Dutch'),
    SupportedLanguage(code: 'sv', shortBadge: 'SV', localeId: 'sv-SE', name: 'Svenska', englishName: 'Swedish'),
    SupportedLanguage(code: 'fi', shortBadge: 'FI', localeId: 'fi-FI', name: 'Suomi', englishName: 'Finnish'),
    SupportedLanguage(code: 'no', shortBadge: 'NO', localeId: 'nb-NO', name: 'Norsk', englishName: 'Norwegian'),
    SupportedLanguage(code: 'da', shortBadge: 'DA', localeId: 'da-DK', name: 'Dansk', englishName: 'Danish'),
    SupportedLanguage(code: 'pl', shortBadge: 'PL', localeId: 'pl-PL', name: 'Polski', englishName: 'Polish'),
    SupportedLanguage(code: 'cs', shortBadge: 'CS', localeId: 'cs-CZ', name: 'Čeština', englishName: 'Czech'),
    SupportedLanguage(code: 'el', shortBadge: 'EL', localeId: 'el-GR', name: 'Ελληνικά', englishName: 'Greek'),
    SupportedLanguage(code: 'tr', shortBadge: 'TR', localeId: 'tr-TR', name: 'Türkçe', englishName: 'Turkish'),
    SupportedLanguage(code: 'ru', shortBadge: 'RU', localeId: 'ru-RU', name: 'Русский', englishName: 'Russian'),
    SupportedLanguage(code: 'uk', shortBadge: 'UK', localeId: 'uk-UA', name: 'Українська', englishName: 'Ukrainian'),
    SupportedLanguage(code: 'ar', shortBadge: 'AR', localeId: 'ar-SA', name: 'العربية', englishName: 'Arabic'),
    SupportedLanguage(code: 'hi', shortBadge: 'HI', localeId: 'hi-IN', name: 'हिन्दी', englishName: 'Hindi'),
    SupportedLanguage(code: 'zh', shortBadge: 'ZH', localeId: 'zh-CN', name: '中文', englishName: 'Chinese Mandarin'),
    SupportedLanguage(code: 'ja', shortBadge: 'JA', localeId: 'ja-JP', name: '日本語', englishName: 'Japanese'),
    SupportedLanguage(code: 'ko', shortBadge: 'KO', localeId: 'ko-KR', name: '한국어', englishName: 'Korean'),
    SupportedLanguage(code: 'vi', shortBadge: 'VI', localeId: 'vi-VN', name: 'Tiếng Việt', englishName: 'Vietnamese'),
    SupportedLanguage(code: 'id', shortBadge: 'ID', localeId: 'id-ID', name: 'Bahasa Indonesia', englishName: 'Indonesian'),
  ];

  static SupportedLanguage byCode(String code) =>
      all.firstWhere((l) => l.code == code, orElse: () => all.first);

  static List<SupportedLanguage> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (l) =>
              l.name.toLowerCase().contains(q) ||
              l.englishName.toLowerCase().contains(q) ||
              l.code.toLowerCase().contains(q) ||
              l.localeId.toLowerCase().contains(q),
        )
        .toList();
  }
}

class AiEngineConfig {
  const AiEngineConfig({
    this.provider = AiProviderType.groqFree,
    this.apiKey = '',
    this.modelId = 'llama-3.1-8b-instant',
    this.customEndpoint = 'http://localhost:11434/v1/chat/completions',
    this.pauseThresholdMs = 850,
    this.whisperVolume = 0.28,
    this.nativeLangCode = 'en',
    this.targetLangCode = 'es',
  });

  final AiProviderType provider;
  final String apiKey;
  final String modelId;
  final String customEndpoint;
  final int pauseThresholdMs;
  final double whisperVolume;
  final String nativeLangCode;
  final String targetLangCode;

  AiEngineConfig copyWith({
    AiProviderType? provider,
    String? apiKey,
    String? modelId,
    String? customEndpoint,
    int? pauseThresholdMs,
    double? whisperVolume,
    String? nativeLangCode,
    String? targetLangCode,
  }) {
    return AiEngineConfig(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      modelId: modelId ?? this.modelId,
      customEndpoint: customEndpoint ?? this.customEndpoint,
      pauseThresholdMs: pauseThresholdMs ?? this.pauseThresholdMs,
      whisperVolume: whisperVolume ?? this.whisperVolume,
      nativeLangCode: nativeLangCode ?? this.nativeLangCode,
      targetLangCode: targetLangCode ?? this.targetLangCode,
    );
  }
}

class WordSuggestion {
  const WordSuggestion({
    required this.word,
    required this.meaningHint,
    required this.latencyMs,
    required this.engineUsed,
    required this.triggerTranscript,
    required this.pauseDurationMs,
  });

  /// Single clean, already-inflected L2 word ready to speak verbatim.
  final String word;

  /// Plain 1–3 word translation shown only in the Personal Notebook for later review.
  final String meaningHint;
  final int latencyMs;
  final String engineUsed;
  final String triggerTranscript;
  final int pauseDurationMs;
}
