import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/ai_engine_config.dart';

class PredictedLexeme {
  const PredictedLexeme({required this.word, this.meaningHint = ''});

  final String word;
  final String meaningHint;
}

/// Pluggable contract: swap or upgrade the AI engine at any time without
/// touching the UI or the hesitation detector.
abstract class WordPredictorEngine {
  Future<PredictedLexeme> predictNextWord({
    required String incompleteTranscript,
    required String targetLanguageName,
    required String nativeLanguageName,
    required AiEngineConfig config,
  });
}

/// Strict sub-2-second response budget matching a natural mid-sentence pause.
const Duration kInferenceLatencyBudget = Duration(milliseconds: 1900);

/// Covers Groq Free Tier (fastest LPU inference, no card), OpenRouter (:free),
/// and any local/custom OpenAI-compatible server (Ollama, LM Studio, vLLM).
class OpenAiCompatiblePredictorEngine implements WordPredictorEngine {
  OpenAiCompatiblePredictorEngine({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<PredictedLexeme> predictNextWord({
    required String incompleteTranscript,
    required String targetLanguageName,
    required String nativeLanguageName,
    required AiEngineConfig config,
  }) async {
    final endpoint = config.provider == AiProviderType.customOpenAi
        ? config.customEndpoint.trim()
        : config.provider.defaultBaseUrl;

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      if (config.apiKey.trim().isNotEmpty)
        'Authorization': 'Bearer ${config.apiKey.trim()}',
    };

    final body = jsonEncode({
      'model': config.modelId.trim().isEmpty
          ? config.provider.defaultModel
          : config.modelId.trim(),
      'temperature': 0.2,
      'max_tokens': 16,
      'messages': [
        {
          'role': 'system',
          'content': _buildSystemPrompt(
            targetLanguageName: targetLanguageName,
            nativeLanguageName: nativeLanguageName,
          ),
        },
        {
          'role': 'user',
          'content': incompleteTranscript,
        },
      ],
    });

    final response = await _client
        .post(Uri.parse(endpoint), headers: headers, body: body)
        .timeout(kInferenceLatencyBudget);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Empty choices from provider');
    }
    final first = choices.first as Map<String, dynamic>;
    final message = first['message'] as Map<String, dynamic>?;
    final rawText = (message?['content'] as String?) ?? '';
    return _parseLexeme(rawText);
  }
}

/// Covers Google Gemini AI Studio Free Tier (`gemini-3.5-flash-lite`, etc.).
class GeminiPredictorEngine implements WordPredictorEngine {
  GeminiPredictorEngine({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<PredictedLexeme> predictNextWord({
    required String incompleteTranscript,
    required String targetLanguageName,
    required String nativeLanguageName,
    required AiEngineConfig config,
  }) async {
    final model = config.modelId.trim().isEmpty
        ? AiProviderType.geminiFree.defaultModel
        : config.modelId.trim();
    final uri = Uri.parse(
      '${AiProviderType.geminiFree.defaultBaseUrl}/models/$model:generateContent?key=${config.apiKey.trim()}',
    );

    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {
            'text': _buildSystemPrompt(
              targetLanguageName: targetLanguageName,
              nativeLanguageName: nativeLanguageName,
            ),
          },
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': incompleteTranscript},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 16,
      },
    });

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(kInferenceLatencyBudget);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gemini HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidates from Gemini');
    }
    final content = (candidates.first as Map<String, dynamic>)['content']
        as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final rawText = (parts != null && parts.isNotEmpty)
        ? ((parts.first as Map<String, dynamic>)['text'] as String? ?? '')
        : '';
    return _parseLexeme(rawText);
  }
}

/// Zero-key offline fallback engine returning ready-to-speak, context-inflected
/// forms with clean plain-language glosses (no grammatical tags).
class OfflineDemoPredictorEngine implements WordPredictorEngine {
  const OfflineDemoPredictorEngine();

  static const Map<String, Map<String, (String, String)>> _collocations = {
    'es': {
      'traer unas': ('servilletas', 'napkins'),
      'traer la': ('cuenta', 'bill / check'),
      'pagar la': ('cuenta', 'bill / check'),
      'receta del': ('médico', 'doctor'),
      'dolor de': ('cabeza', 'headache'),
      'necesito un': ('enchufe', 'power outlet'),
      'reparar la': ('bicicleta', 'bicycle'),
      'ayer yo': ('llegué', 'arrived'),
      'ayer por la tarde': ('llegué', 'arrived'),
      'tengo que': ('terminar', 'finish'),
      'tren de la': ('mañana', 'morning'),
      'taza de': ('café', 'coffee'),
      'vaso de': ('agua', 'water'),
      'punta de la': ('lengua', 'tongue'),
      'estación de': ('tren', 'train'),
      'tomar una': ('decisión', 'decision'),
      'por ciento de': ('propina', 'tip'),
      'buscando el': ('camino', 'way / path'),
      'buscando unas': ('llaves', 'keys'),
    },
    'en': {
      'tip of my': ('tongue', 'lengua / lingua'),
      'missed my morning': ('train', 'tren / treno'),
      'pharmacy for my': ('prescription', 'receta'),
      'plug in my': ('charger', 'cargador'),
      'schedule a': ('meeting', 'reunión'),
      'send me the': ('link', 'enlace'),
      'looking for the': ('station', 'estación'),
      'cup of': ('coffee', 'café'),
      'glass of': ('water', 'agua'),
      'pay the': ('bill', 'cuenta'),
      'improve my': ('fluency', 'fluidez'),
    },
    'fr': {
      'bout de la': ('langue', 'tongue'),
      'tasse de': ('café', 'coffee'),
      'payer l': ('addition', 'bill'),
      'cherche la': ('gare', 'train station'),
      'ordonnance du': ('médecin', 'doctor'),
    },
    'de': {
      'auf der': ('Zunge', 'tongue'),
      'tasse': ('Kaffee', 'coffee'),
      'suche den': ('Bahnhof', 'train station'),
      'rezept vom': ('Arzt', 'doctor'),
    },
    'it': {
      'punta della': ('lingua', 'tongue'),
      'tazza di': ('caffè', 'coffee'),
      'pagare il': ('conto', 'bill'),
      'ricetta del': ('medico', 'doctor'),
    },
    'fi': {
      'kuppi': ('kahvia', 'coffee'),
      'etsin': ('asemaa', 'station'),
      'tarvitsen': ('laturin', 'charger'),
    },
  };

  @override
  Future<PredictedLexeme> predictNextWord({
    required String incompleteTranscript,
    required String targetLanguageName,
    required String nativeLanguageName,
    required AiEngineConfig config,
  }) async {
    final lower = incompleteTranscript.toLowerCase().trim();
    final langMap = _collocations[config.targetLangCode] ?? _collocations['es']!;

    for (final entry in langMap.entries) {
      if (lower.endsWith(entry.key) || lower.contains(entry.key)) {
        return PredictedLexeme(
          word: entry.value.$1,
          meaningHint: entry.value.$2,
        );
      }
    }

    if (config.targetLangCode == 'en') {
      return const PredictedLexeme(word: 'idea', meaningHint: 'idea');
    }
    if (config.targetLangCode == 'fi') {
      return const PredictedLexeme(word: 'sana', meaningHint: 'word');
    }

    return const PredictedLexeme(word: 'palabra', meaningHint: 'word');
  }
}

class AiPredictorService {
  AiPredictorService({
    WordPredictorEngine? openAiEngine,
    WordPredictorEngine? geminiEngine,
    WordPredictorEngine? offlineEngine,
  })  : _openAiEngine = openAiEngine ?? OpenAiCompatiblePredictorEngine(),
        _geminiEngine = geminiEngine ?? GeminiPredictorEngine(),
        _offlineEngine = offlineEngine ?? const OfflineDemoPredictorEngine();

  final WordPredictorEngine _openAiEngine;
  final WordPredictorEngine _geminiEngine;
  final WordPredictorEngine _offlineEngine;

  Future<WordSuggestion> suggestSingleWord({
    required String incompleteTranscript,
    required AiEngineConfig config,
    int pauseDurationMs = 850,
  }) async {
    final stopwatch = Stopwatch()..start();
    final targetLang = SupportedLanguage.byCode(config.targetLangCode).name;
    final nativeLang = SupportedLanguage.byCode(config.nativeLangCode).name;

    final bool missingKey =
        config.provider.requiresApiKey && config.apiKey.trim().isEmpty;

    WordPredictorEngine engine;
    String engineLabel;

    if (config.provider == AiProviderType.offlineDemo || missingKey) {
      engine = _offlineEngine;
      engineLabel = missingKey ? 'Local Contextual' : 'Local Demo';
    } else if (config.provider == AiProviderType.geminiFree) {
      engine = _geminiEngine;
      engineLabel = 'Gemini (${config.modelId})';
    } else {
      engine = _openAiEngine;
      engineLabel = '${config.provider.name} (${config.modelId})';
    }

    try {
      final result = await engine.predictNextWord(
        incompleteTranscript: incompleteTranscript,
        targetLanguageName: targetLang,
        nativeLanguageName: nativeLang,
        config: config,
      );
      stopwatch.stop();
      return WordSuggestion(
        word: result.word.isEmpty ? '...' : result.word,
        meaningHint: result.meaningHint,
        latencyMs: stopwatch.elapsedMilliseconds,
        engineUsed: engineLabel,
        triggerTranscript: incompleteTranscript,
        pauseDurationMs: pauseDurationMs,
      );
    } catch (_) {
      final fallback = await _offlineEngine.predictNextWord(
        incompleteTranscript: incompleteTranscript,
        targetLanguageName: targetLang,
        nativeLanguageName: nativeLang,
        config: config,
      );
      stopwatch.stop();
      return WordSuggestion(
        word: fallback.word,
        meaningHint: fallback.meaningHint,
        latencyMs: stopwatch.elapsedMilliseconds,
        engineUsed: 'Local Fallback',
        triggerTranscript: incompleteTranscript,
        pauseDurationMs: pauseDurationMs,
      );
    }
  }
}

String _buildSystemPrompt({
  required String targetLanguageName,
  required String nativeLanguageName,
}) {
  return 'You are "TipTongue", an ultra-fast open-domain next-word completion assistant '
      'for a $nativeLanguageName speaker conversing in $targetLanguageName in any real-world setting. '
      'Infer the topic, register, and missing word solely from the unfinished spoken sentence — never assume a fixed domain. '
      'The speaker paused mid-sentence and will say your word aloud verbatim without pausing to conjugate it. '
      'Reply strictly in the format: WORD | plain 1-3 word $nativeLanguageName meaning '
      '(examples: servilletas | napkins, llegué | arrived, receta | prescription, enchufe | outlet). '
      'WORD must be EXACTLY ONE single word in $targetLanguageName ALREADY properly conjugated, '
      'declined, and matched in tense, person, gender, and number to continue the unfinished sentence directly. '
      'Never include quotes, explanations, or grammar labels like "fem. noun", "masc. noun", or "verb".';
}

final RegExp _grammarTagPattern = RegExp(
  r'\s*(?:[·•\-|]\s*)?(?:fem\.?|masc\.?|neut\.?|pl\.?|sg\.?)?\s*\b(?:noun|verb|adj\.?|adjective|adv\.?|adverb|pronoun)\b\.?',
  caseSensitive: false,
);

PredictedLexeme _parseLexeme(String raw) {
  final parts = raw.split('|');
  final rawWord = parts.first
      .trim()
      .replaceAll(RegExp(r'^["\x27«“]+|["\x27»”.!?,;:]+$'), '')
      .trim();
  final singleWord =
      rawWord.isEmpty ? '' : rawWord.split(RegExp(r'\s+')).first;
  final rawHint = parts.length > 1 ? parts.sublist(1).join('|').trim() : '';
  final cleanHint = rawHint.replaceAll(_grammarTagPattern, '').trim();
  return PredictedLexeme(word: singleWord, meaningHint: cleanHint);
}
