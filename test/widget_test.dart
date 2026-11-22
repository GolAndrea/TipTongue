import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tip_on_my_tongue/data/repositories/settings_repository.dart';
import 'package:tip_on_my_tongue/data/services/ai_predictor_service.dart';
import 'package:tip_on_my_tongue/data/services/glasses_connection_service.dart';
import 'package:tip_on_my_tongue/data/services/speech_input_service.dart';
import 'package:tip_on_my_tongue/data/services/whisper_tts_service.dart';
import 'package:tip_on_my_tongue/domain/models/ai_engine_config.dart';
import 'package:tip_on_my_tongue/domain/models/glasses_device.dart';
import 'package:tip_on_my_tongue/domain/use_cases/hesitation_detector.dart';
import 'package:tip_on_my_tongue/main.dart';
import 'package:tip_on_my_tongue/ui/features/session/view_models/session_view_model.dart';

class _FakeCustomEngine implements WordPredictorEngine {
  @override
  Future<PredictedLexeme> predictNextWord({
    required String incompleteTranscript,
    required String targetLanguageName,
    required String nativeLanguageName,
    required AiEngineConfig config,
  }) async {
    return const PredictedLexeme(
      word: 'fluidez',
      meaningHint: 'fluency',
    );
  }
}

class _FakeGlassesService extends GlassesConnectionService {
  final List<bool> hfpHistory = [];
  final List<String> pushedDisplayWords = [];
  int clearHudCalls = 0;

  @override
  Stream<GlassesDeviceTelemetry> get telemetryStream =>
      const Stream<GlassesDeviceTelemetry>.empty();

  @override
  Future<GlassesDeviceTelemetry> getDatStatus() async =>
      const GlassesDeviceTelemetry(
        datAvailable: true,
        datRegistrationState: 'registered',
      );

  @override
  Future<void> setGlassesAudioRouting(bool hfpEnabled) async {
    hfpHistory.add(hfpEnabled);
  }

  @override
  Future<bool> pushDisplayWord({
    required String word,
    required String meaningHint,
    required String languagePair,
  }) async {
    pushedDisplayWords.add(word);
    return true;
  }

  @override
  Future<void> clearDisplayHud() async {
    clearHudCalls++;
  }
}

class _NoOpSpeechService extends SpeechInputService {
  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async =>
      false;

  @override
  Future<void> stopListening() async {}
}

class _NoOpWhisperService extends WhisperTtsService {
  @override
  Future<void> speakWhisper({
    required String word,
    required String localeId,
    required double volume,
  }) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  group('HesitationDetector', () {
    const detector = HesitationDetector();

    test('triggers on mid-phrase pause with dangling syntax', () {
      expect(
        detector.shouldTrigger(
          transcript: 'Disculpe nos puede traer la',
          silenceMs: 900,
          thresholdMs: 850,
        ),
        isTrue,
      );
    });

    test('triggers slightly earlier on explicit article/preposition cliff', () {
      expect(
        detector.shouldTrigger(
          transcript: 'Ayer perdí el tren de la',
          silenceMs: 740,
          thresholdMs: 850,
        ),
        isTrue,
      );
    });

    test('ignores completed sentences with terminal punctuation', () {
      expect(
        detector.shouldTrigger(
          transcript: 'Muchas gracias por su ayuda.',
          silenceMs: 1500,
          thresholdMs: 850,
        ),
        isFalse,
      );
    });

    test('ignores short pauses below threshold', () {
      expect(
        detector.shouldTrigger(
          transcript: 'Estoy buscando el',
          silenceMs: 300,
          thresholdMs: 850,
        ),
        isFalse,
      );
    });

    test('does not re-trigger on identical already-prompted transcript', () {
      expect(
        detector.shouldTrigger(
          transcript: 'Estoy buscando el',
          silenceMs: 1200,
          thresholdMs: 850,
          lastTriggeredTranscript: 'Estoy buscando el',
        ),
        isFalse,
      );
    });
  });

  group('GlassesDevice model recognition & camera-off policy', () {
    test('distinguishes Gen 2, Ray-Ban Meta Audio, and Display models', () {
      final gen2 = GlassesDevice.fromBluetoothDevice(
        id: '1',
        rawName: 'Ray-Ban Meta Gen 2',
      );
      final audio = GlassesDevice.fromBluetoothDevice(
        id: '2',
        rawName: 'Ray-Ban Meta Audio',
      );
      final display = GlassesDevice.fromBluetoothDevice(
        id: '3',
        rawName: 'Meta Ray-Ban Display',
      );

      expect(gen2.generation, GlassesGeneration.rayBanMetaGen2);
      expect(gen2.supportsDisplay, isFalse);
      expect(gen2.recommendedWhisperEnabled, isTrue);
      expect(gen2.isCameraForcedOff, isTrue);

      expect(audio.generation, GlassesGeneration.rayBanMetaAudio);
      expect(audio.supportsDisplay, isFalse);
      expect(audio.recommendedWhisperEnabled, isTrue);
      expect(audio.isCameraForcedOff, isTrue);

      expect(display.generation, GlassesGeneration.rayBanMetaDisplay);
      expect(display.supportsDisplay, isTrue);
      expect(display.recommendedHudEnabled, isTrue);
      expect(display.isCameraForcedOff, isTrue);
    });
  });

  group('AiPredictorService modular swappability', () {
    test('falls back cleanly to Spanish offline engine when API key is empty',
        () async {
      final service = AiPredictorService();
      final res = await service.suggestSingleWord(
        incompleteTranscript: 'Disculpe, nos puede traer la',
        config: const AiEngineConfig(
          provider: AiProviderType.groqFree,
          apiKey: '',
          nativeLangCode: 'en',
          targetLangCode: 'es',
        ),
      );
      expect(res.word, 'cuenta');
      expect(res.meaningHint, contains('bill'));
      expect(res.meaningHint.toLowerCase(), isNot(contains('noun')));
    });

    test('returns context-inflected plural and conjugated forms without grammar tags',
        () async {
      final service = AiPredictorService();

      final pluralRes = await service.suggestSingleWord(
        incompleteTranscript: 'Disculpe, nos puede traer unas',
        config: const AiEngineConfig(
          provider: AiProviderType.offlineDemo,
          nativeLangCode: 'en',
          targetLangCode: 'es',
        ),
      );
      expect(pluralRes.word, 'servilletas');
      expect(pluralRes.meaningHint, 'napkins');
      expect(pluralRes.meaningHint.toLowerCase(), isNot(contains('noun')));

      final pastRes = await service.suggestSingleWord(
        incompleteTranscript: 'Ayer por la tarde yo',
        config: const AiEngineConfig(
          provider: AiProviderType.offlineDemo,
          nativeLangCode: 'en',
          targetLangCode: 'es',
        ),
      );
      expect(pastRes.word, 'llegué');
      expect(pastRes.meaningHint.toLowerCase(), isNot(contains('verb')));

      // Open-domain deduction across arbitrary real-world settings (medical, home)
      final medicalRes = await service.suggestSingleWord(
        incompleteTranscript: 'Necesito recoger la receta del',
        config: const AiEngineConfig(
          provider: AiProviderType.offlineDemo,
          nativeLangCode: 'en',
          targetLangCode: 'es',
        ),
      );
      expect(medicalRes.word, 'médico');

      // Latency budget strictly fits within a natural < 2 s user pause
      expect(kInferenceLatencyBudget.inMilliseconds, lessThanOrEqualTo(2000));
    });

    test('exposes 24 searchable supported languages', () {
      expect(SupportedLanguage.all.length, 24);
      final fi = SupportedLanguage.search('finnish');
      expect(fi.any((l) => l.code == 'fi' && l.name == 'Suomi'), isTrue);
      final ja = SupportedLanguage.search('ja');
      expect(ja.any((l) => l.code == 'ja' && l.englishName == 'Japanese'), isTrue);
    });

    test('supports swapping custom WordPredictorEngine implementation',
        () async {
      final service = AiPredictorService(openAiEngine: _FakeCustomEngine());
      final res = await service.suggestSingleWord(
        incompleteTranscript: 'Quiero mejorar mi',
        config: const AiEngineConfig(
          provider: AiProviderType.groqFree,
          apiKey: 'gsk_test_key',
        ),
      );
      expect(res.word, 'fluidez');
    });
  });

  group('Meta AUP privacy-by-design & DAT v1.0.1 DeviceState', () {
    test('purges ephemeral RAM transcript after TTL and never saves dialogue',
        () async {
      SharedPreferences.setMockInitialValues({});
      final fakeGlasses = _FakeGlassesService();
      final vm = SessionViewModel(
        settingsRepository: SettingsRepository(),
        glassesService: fakeGlasses,
        speechService: _NoOpSpeechService(),
        whisperService: _NoOpWhisperService(),
        predictorService: AiPredictorService(),
        ephemeralBufferTtl: const Duration(milliseconds: 60),
      );
      await vm.init();
      await vm.selectGlassesDevice(
        const GlassesDevice(
          id: 'real_display',
          name: 'Meta Ray-Ban Display',
          generation: GlassesGeneration.rayBanMetaDisplay,
          isSimulated: false,
        ),
      );

      // 1. Ephemeral buffer auto-purges on TTL expiry
      vm.ingestTranscript('Estoy buscando la');
      expect(vm.liveTranscript, isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(vm.liveTranscript, isEmpty);

      // 2. Manual rescue pushes single word to DAT Display and scrubs stored transcript
      vm.ingestTranscript('Disculpe, nos puede traer la');
      await vm.triggerManualRescue();
      expect(vm.liveTranscript, isEmpty);
      expect(vm.recentSuggestions.first.word, 'cuenta');
      expect(vm.recentSuggestions.first.triggerTranscript, isEmpty);
      expect(fakeGlasses.pushedDisplayWords, contains('cuenta'));

      vm.dispose();
    });

    test('auto-pauses on doffed/folded glasses and switches HFP <-> A2DP',
        () async {
      SharedPreferences.setMockInitialValues({});
      final fakeGlasses = _FakeGlassesService();
      final vm = SessionViewModel(
        settingsRepository: SettingsRepository(),
        glassesService: fakeGlasses,
        speechService: _NoOpSpeechService(),
        whisperService: _NoOpWhisperService(),
        predictorService: AiPredictorService(),
      );
      await vm.init();
      await vm.selectGlassesDevice(
        const GlassesDevice(
          id: 'real_gen2',
          name: 'Ray-Ban Meta Gen 2',
          generation: GlassesGeneration.rayBanMetaGen2,
          isSimulated: false,
        ),
      );

      // Idle keeps A2DP (hfp=false)
      expect(fakeGlasses.hfpHistory.last, isFalse);

      await vm.startSession();
      expect(vm.isSessionActive, isTrue);
      expect(fakeGlasses.hfpHistory.last, isTrue);

      // DAT DeviceState reports wearer removed glasses -> auto-pause & release to A2DP
      await vm.handleDeviceTelemetry(
        const GlassesDeviceTelemetry(
          datAvailable: true,
          isDonned: false,
          isHingeOpen: true,
          batteryLevel: 12,
        ),
      );
      expect(vm.isSessionActive, isFalse);
      expect(vm.autoPausedByGlassesState, isTrue);
      expect(vm.isPowerSaverActive, isTrue);
      expect(fakeGlasses.hfpHistory.last, isFalse);

      vm.dispose();
    });
  });

  testWidgets(
      'HomeScreen stays calm, highlights 24 languages, and keeps privacy in settings',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final vm = SessionViewModel(
      settingsRepository: SettingsRepository(),
      glassesService: _FakeGlassesService(),
      speechService: _NoOpSpeechService(),
      whisperService: _NoOpWhisperService(),
      predictorService: AiPredictorService(),
    );
    addTearDown(vm.dispose);
    await vm.init();

    await tester.pumpWidget(TipOnMyTongueApp(viewModel: vm));
    await tester.pump();

    expect(find.text('TipTongue'), findsOneWidget);
    expect(find.text('EN → Español · 24'), findsOneWidget);
    // Open-domain: zero manual scenario chips cluttering Home
    expect(find.text('En el café'), findsNothing);
    expect(find.text('Trabajo'), findsNothing);
    expect(find.text('Device & privacy'), findsOneWidget);
    expect(find.text('Camera & LED off'), findsNothing);
    expect(find.textContaining('600×600'), findsNothing);
    expect(find.textContaining('mwdat-display'), findsNothing);
    expect(
      find.text('No audio recorded · Ephemeral RAM buffer'),
      findsNothing,
    );
    expect(find.text('Personal notebook · Today'), findsOneWidget);
    expect(find.text('Start speaking in Español'), findsOneWidget);
    expect(find.textContaining('850ms'), findsNothing);
    expect(vm.config.pauseThresholdMs, 850);
    expect(vm.ephemeralBufferTtl, const Duration(seconds: 30));

    // Tapping the quiet bottom device strip opens the dedicated Device & Privacy sheet
    await tester.tap(find.text('Device & privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Device & Privacy'), findsOneWidget);
    expect(find.text('Camera off'), findsOneWidget);
    expect(find.textContaining('erased after 30 seconds'), findsOneWidget);
    expect(find.textContaining('600×600'), findsNothing);
    expect(find.textContaining('mwdat-display'), findsNothing);

    // Dismiss sheet and verify searchable 24-language picker
    Navigator.of(tester.element(find.text('Device & Privacy'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('EN → Español · 24'));
    await tester.pumpAndSettle();
    expect(find.text('24 supported'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'finnish');
    await tester.pumpAndSettle();
    expect(find.text('Suomi'), findsOneWidget);
    await tester.tap(find.text('Suomi'));
    await tester.pumpAndSettle();
    expect(vm.config.targetLangCode, 'fi');
  });
}
