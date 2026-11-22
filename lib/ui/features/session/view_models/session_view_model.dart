import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/settings_repository.dart';
import '../../../../data/services/ai_predictor_service.dart';
import '../../../../data/services/glasses_connection_service.dart';
import '../../../../data/services/speech_input_service.dart';
import '../../../../data/services/whisper_tts_service.dart';
import '../../../../domain/models/ai_engine_config.dart';
import '../../../../domain/models/glasses_device.dart';
import '../../../../domain/use_cases/hesitation_detector.dart';

class SessionViewModel extends ChangeNotifier {
  SessionViewModel({
    required this._settingsRepository,
    required this._glassesService,
    required this._speechService,
    required this._whisperService,
    required this._predictorService,
    this._hesitationDetector = const HesitationDetector(),
    this.ephemeralBufferTtl = const Duration(seconds: 30),
  });

  final SettingsRepository _settingsRepository;
  final GlassesConnectionService _glassesService;
  final SpeechInputService _speechService;
  final WhisperTtsService _whisperService;
  final AiPredictorService _predictorService;
  final HesitationDetector _hesitationDetector;

  /// Meta Wearables AUP compliance: live speech context stays in RAM only for a
  /// brief rolling window and is automatically purged after rescue or timeout.
  final Duration ephemeralBufferTtl;

  AiEngineConfig _config = const AiEngineConfig();
  AiEngineConfig get config => _config;

  GlassesDevice _connectedDevice = GlassesDevice.standalone();
  GlassesDevice get connectedDevice => _connectedDevice;

  GlassesDeviceTelemetry _telemetry = const GlassesDeviceTelemetry();
  GlassesDeviceTelemetry get telemetry => _telemetry;

  List<GlassesDevice> _discoveredBluetoothDevices = const [];
  List<GlassesDevice> get discoveredBluetoothDevices =>
      _discoveredBluetoothDevices;

  List<GlassesDevice> get simulatedDevices =>
      _glassesService.getSimulatedModels();

  bool _isScanningGlasses = false;
  bool get isScanningGlasses => _isScanningGlasses;

  bool _hudEnabled = true;
  bool get hudEnabled => _hudEnabled;

  bool _whisperEnabled = true;
  bool get whisperEnabled => _whisperEnabled;

  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;

  bool _isPredicting = false;
  bool get isPredicting => _isPredicting;

  bool _isHfpAudioActive = false;
  bool get isHfpAudioActive => _isHfpAudioActive;

  bool _autoPausedByGlassesState = false;
  bool get autoPausedByGlassesState => _autoPausedByGlassesState;

  String _liveTranscript = '';
  String get liveTranscript => _liveTranscript;

  WordSuggestion? _activeSuggestion;
  WordSuggestion? get activeSuggestion => _activeSuggestion;
  String? get activePromptWord => _activeSuggestion?.word;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  int _currentSilenceMs = 0;
  int get currentSilenceMs => _currentSilenceMs;

  DateTime? _lastSpeechAt;
  String? _lastTriggeredTranscript;
  Timer? _pauseWatchdog;
  Timer? _hudAutoClearTimer;
  Timer? _ephemeralPurgeTimer;
  StreamSubscription<GlassesDeviceTelemetry>? _telemetrySub;

  final List<WordSuggestion> _recentSuggestions = [];
  List<WordSuggestion> get recentSuggestions =>
      List.unmodifiable(_recentSuggestions);

  bool get isPowerSaverActive =>
      _telemetry.isLowBattery || _telemetry.isThermallyConstrained;

  String get activeAudioProfileLabel =>
      _isHfpAudioActive ? 'HFP Mic' : 'A2DP Hi-Fi';

  Future<void> init() async {
    _config = await _settingsRepository.loadConfig();
    _applyDeviceProfile(_connectedDevice);

    _telemetry = await _glassesService.getDatStatus();
    if (_telemetry.datAvailable) {
      _telemetrySub = _glassesService.telemetryStream.listen(
        handleDeviceTelemetry,
      );
    }
    notifyListeners();
  }

  /// Processes live Meta DAT v1.0.1 DeviceState updates (donState, hingeState,
  /// batteryLevel, thermalLevel). Automatically pauses active listening when
  /// the wearer removes or folds the glasses.
  Future<void> handleDeviceTelemetry(GlassesDeviceTelemetry state) async {
    _telemetry = state;

    if (_isSessionActive && state.shouldAutoPause) {
      await stopSession();
      _autoPausedByGlassesState = true;
      _statusMessage = !state.isHingeOpen
          ? 'Auto-paused: glasses folded (hinge closed).'
          : 'Auto-paused: glasses removed (doffed).';
    } else if (_autoPausedByGlassesState && !state.shouldAutoPause) {
      _autoPausedByGlassesState = false;
      _statusMessage = 'Glasses worn again — tap Start to resume.';
    } else if (state.isLowBattery || state.isThermallyConstrained) {
      _statusMessage = state.isThermallyConstrained
          ? 'Thermal conservation active: using local offline predictor.'
          : 'Low glasses battery (${state.batteryLevel}%): local offline predictor active.';
    }

    notifyListeners();
  }

  Future<void> scanForRealGlasses() async {
    _isScanningGlasses = true;
    notifyListeners();
    try {
      _discoveredBluetoothDevices =
          await _glassesService.scanRealBluetoothGlasses();
      _telemetry = await _glassesService.getDatStatus();
    } finally {
      _isScanningGlasses = false;
      notifyListeners();
    }
  }

  Future<void> startDatRegistration() async {
    final started = await _glassesService.startDatRegistration();
    _statusMessage = started
        ? 'Opening Meta AI registration flow (camera module excluded).'
        : 'Meta DAT native registration requires Android/iOS build with Meta AI app.';
    notifyListeners();
  }

  Future<void> toggleOfficialMockDisplay(bool enabled) async {
    final updated = await _glassesService.setOfficialMockDisplay(enabled);
    _telemetry = updated;
    if (enabled && updated.isOfficialMockActive) {
      final mockDisplay = const GlassesDevice(
        id: 'dat_mock_display',
        name: 'Meta Ray-Ban Display (DAT Mock)',
        generation: GlassesGeneration.rayBanMetaDisplay,
        isSimulated: true,
      );
      await selectGlassesDevice(mockDisplay);
      _statusMessage =
          'Official Meta DAT MockDeviceKit Display active (Camera & LED off).';
    } else if (!enabled) {
      _statusMessage = 'Official Meta DAT MockDeviceKit disabled.';
    } else {
      _statusMessage =
          'Meta DAT MockDeviceKit runs on Android/iOS native builds; using built-in Web simulator.';
    }
    notifyListeners();
  }

  /// Connects a real or simulated Ray-Ban model, configures output channels,
  /// enforces Camera OFF, and notifies relevant usage settings.
  Future<void> selectGlassesDevice(GlassesDevice device) async {
    _connectedDevice = device;
    _applyDeviceProfile(device);

    // Keep A2DP while idle; HFP engages only while a live session is running.
    final useBtHfp = _isSessionActive && _usesPhysicalBluetoothGlasses(device);
    await _setAudioRouting(useBtHfp);

    _statusMessage = device.usageNotificationBody;
    notifyListeners();
  }

  bool _usesPhysicalBluetoothGlasses(GlassesDevice device) =>
      !device.isSimulated &&
      device.generation != GlassesGeneration.standalonePhone;

  Future<void> _setAudioRouting(bool hfpEnabled) async {
    _isHfpAudioActive = hfpEnabled;
    await _glassesService.setGlassesAudioRouting(hfpEnabled);
  }

  void _applyDeviceProfile(GlassesDevice device) {
    if (device.generation == GlassesGeneration.standalonePhone) {
      _hudEnabled = true;
      _whisperEnabled = true;
    } else if (device.supportsDisplay) {
      _hudEnabled = true;
      _whisperEnabled = false;
    } else {
      // Gen 1, Gen 2, and Ray-Ban Meta Audio are screenless: Whisper mandatory.
      _hudEnabled = false;
      _whisperEnabled = true;
    }
  }

  void toggleWhisper(bool enabled) {
    if (!_connectedDevice.supportsDisplay &&
        _connectedDevice.generation != GlassesGeneration.standalonePhone) {
      return;
    }
    _whisperEnabled = enabled;
    notifyListeners();
  }

  Future<void> updateConfig(AiEngineConfig newConfig) async {
    _config = newConfig;
    await _settingsRepository.saveConfig(newConfig);
    notifyListeners();
  }

  /// Replays the gentle whisper pronunciation when tapping a saved notebook entry.
  /// Ensures A2DP high-fidelity audio profile when not actively capturing mic audio.
  Future<void> replayWordWhisper(String word) async {
    if (!_isSessionActive && _usesPhysicalBluetoothGlasses(_connectedDevice)) {
      await _setAudioRouting(false);
    }
    final locale = SupportedLanguage.byCode(_config.targetLangCode).localeId;
    await _whisperService.speakWhisper(
      word: word,
      localeId: locale,
      volume: _config.whisperVolume,
    );
  }

  Future<void> toggleLiveSession() async {
    if (_isSessionActive) {
      await stopSession();
    } else {
      await startSession();
    }
  }

  Future<void> startSession() async {
    _autoPausedByGlassesState = false;

    if (_usesPhysicalBluetoothGlasses(_connectedDevice)) {
      await _setAudioRouting(true);
    }

    final ready = await _speechService.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (_isSessionActive) {
            final locale =
                SupportedLanguage.byCode(_config.targetLangCode).localeId;
            _speechService.startListening(
              localeId: locale,
              onTranscript: _onSpeechTranscript,
            );
          }
        }
      },
      onError: (err) {
        _statusMessage =
            'Microphone unavailable ($err). Check system audio permissions.';
        notifyListeners();
      },
    );

    _isSessionActive = true;
    _currentSilenceMs = 0;
    _lastSpeechAt = null;
    _startPauseWatchdog();
    notifyListeners();

    if (ready) {
      final locale = SupportedLanguage.byCode(_config.targetLangCode).localeId;
      await _speechService.startListening(
        localeId: locale,
        onTranscript: _onSpeechTranscript,
      );
    } else {
      _statusMessage =
          'Speech recognition unavailable on this device: enable microphone permissions.';
      notifyListeners();
    }
  }

  Future<void> stopSession() async {
    _isSessionActive = false;
    _pauseWatchdog?.cancel();
    _hudAutoClearTimer?.cancel();
    _purgeEphemeralTranscript();
    _currentSilenceMs = 0;
    await _speechService.stopListening();
    await _whisperService.stop();
    await _glassesService.clearDisplayHud();

    // Release Bluetooth HFP back to high-fidelity A2DP when session pauses.
    if (_isHfpAudioActive) {
      await _setAudioRouting(false);
    }
    notifyListeners();
  }

  /// Manual rescue hook (usable from UI or temple tap / Neural Band pinch)
  /// when ambient noise prevents automatic silence detection.
  Future<void> triggerManualRescue() async {
    if (_isPredicting || _liveTranscript.trim().isEmpty) return;
    await _triggerWordRescue(_liveTranscript, _currentSilenceMs);
  }

  /// Exposed for unit testing and speech stream ingestion: stores only the
  /// ephemeral rolling utterance in RAM with an automatic purge timer.
  void ingestTranscript(String words, {bool isFinal = false}) {
    _onSpeechTranscript(words, isFinal);
  }

  void _onSpeechTranscript(String words, bool isFinal) {
    if (words.trim().isEmpty) return;

    if (words.trim() != _liveTranscript.trim()) {
      if (_activeSuggestion != null) {
        _activeSuggestion = null;
        _hudAutoClearTimer?.cancel();
        unawaited(_glassesService.clearDisplayHud());
      }
      _liveTranscript = words;
      _lastSpeechAt = DateTime.now();
      _currentSilenceMs = 0;
      _scheduleEphemeralPurge();
      notifyListeners();
    }
  }

  void _scheduleEphemeralPurge() {
    _ephemeralPurgeTimer?.cancel();
    _ephemeralPurgeTimer = Timer(ephemeralBufferTtl, () {
      if (_liveTranscript.isNotEmpty) {
        _purgeEphemeralTranscript();
        notifyListeners();
      }
    });
  }

  void _purgeEphemeralTranscript() {
    _ephemeralPurgeTimer?.cancel();
    _liveTranscript = '';
    _lastSpeechAt = null;
  }

  void _startPauseWatchdog() {
    _pauseWatchdog?.cancel();
    _pauseWatchdog = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_isSessionActive || _lastSpeechAt == null || _isPredicting) return;

      _currentSilenceMs =
          DateTime.now().difference(_lastSpeechAt!).inMilliseconds;
      notifyListeners();

      final effectiveThreshold = isPowerSaverActive
          ? (_config.pauseThresholdMs * 1.25).round()
          : _config.pauseThresholdMs;

      final shouldPrompt = _hesitationDetector.shouldTrigger(
        transcript: _liveTranscript,
        silenceMs: _currentSilenceMs,
        thresholdMs: effectiveThreshold,
        lastTriggeredTranscript: _lastTriggeredTranscript,
      );

      if (shouldPrompt) {
        _triggerWordRescue(_liveTranscript, _currentSilenceMs);
      }
    });
  }

  Future<void> _triggerWordRescue(
    String stalledTranscript,
    int detectedPauseMs,
  ) async {
    _isPredicting = true;
    _lastTriggeredTranscript = stalledTranscript;
    notifyListeners();

    try {
      final cleanContext =
          _hesitationDetector.cleanContextForPrediction(stalledTranscript);

      final effectiveConfig = isPowerSaverActive
          ? _config.copyWith(provider: AiProviderType.offlineDemo)
          : _config;

      final rawSuggestion = await _predictorService.suggestSingleWord(
        incompleteTranscript: cleanContext,
        config: effectiveConfig,
        pauseDurationMs: detectedPauseMs,
      );

      // Meta AUP privacy-by-design: never retain raw spoken conversation text
      // in Personal Notebook history — keep only the rescued word + gloss.
      final sanitizedSuggestion = WordSuggestion(
        word: rawSuggestion.word,
        meaningHint: rawSuggestion.meaningHint,
        triggerTranscript: '',
        engineUsed: rawSuggestion.engineUsed,
        latencyMs: rawSuggestion.latencyMs,
        pauseDurationMs: rawSuggestion.pauseDurationMs,
      );

      _recentSuggestions.insert(0, sanitizedSuggestion);
      if (_recentSuggestions.length > 10) {
        _recentSuggestions.removeLast();
      }

      // Immediately purge the rolling speech context from RAM after rescue.
      _purgeEphemeralTranscript();

      _activeSuggestion = sanitizedSuggestion;
      if (_hudEnabled) {
        if (_connectedDevice.supportsDisplay) {
          final nativeBadge =
              SupportedLanguage.byCode(_config.nativeLangCode).shortBadge;
          final targetBadge =
              SupportedLanguage.byCode(_config.targetLangCode).shortBadge;
          unawaited(
            _glassesService.pushDisplayWord(
              word: sanitizedSuggestion.word,
              meaningHint: sanitizedSuggestion.meaningHint,
              languagePair: '$nativeBadge → $targetBadge',
            ),
          );
        }
        _hudAutoClearTimer?.cancel();
        _hudAutoClearTimer = Timer(const Duration(milliseconds: 4200), () {
          _activeSuggestion = null;
          unawaited(_glassesService.clearDisplayHud());
          notifyListeners();
        });
      }

      if (_whisperEnabled) {
        final locale =
            SupportedLanguage.byCode(_config.targetLangCode).localeId;
        await _whisperService.speakWhisper(
          word: sanitizedSuggestion.word,
          localeId: locale,
          volume: _config.whisperVolume,
        );
      }
    } finally {
      _isPredicting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pauseWatchdog?.cancel();
    _hudAutoClearTimer?.cancel();
    _ephemeralPurgeTimer?.cancel();
    _telemetrySub?.cancel();
    _speechService.stopListening();
    _whisperService.stop();
    super.dispose();
  }
}
