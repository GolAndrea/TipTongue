import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/ai_engine_config.dart';

class SettingsRepository {
  static const _kProvider = 'ai_provider';
  static const _kApiKey = 'ai_api_key';
  static const _kModelId = 'ai_model_id';
  static const _kCustomEndpoint = 'ai_custom_endpoint';
  static const _kPauseMs = 'pause_threshold_ms';
  static const _kWhisperVol = 'whisper_volume';
  static const _kNativeLang = 'native_lang';
  static const _kTargetLang = 'target_lang';

  Future<AiEngineConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final providerIdx = prefs.getInt(_kProvider) ?? 0;
    final provider = AiProviderType.values[
        providerIdx.clamp(0, AiProviderType.values.length - 1)];

    return AiEngineConfig(
      provider: provider,
      apiKey: prefs.getString(_kApiKey) ?? '',
      modelId: prefs.getString(_kModelId) ?? provider.defaultModel,
      customEndpoint: prefs.getString(_kCustomEndpoint) ??
          AiProviderType.customOpenAi.defaultBaseUrl,
      pauseThresholdMs: prefs.getInt(_kPauseMs) ?? 850,
      whisperVolume: prefs.getDouble(_kWhisperVol) ?? 0.28,
      nativeLangCode: prefs.getString(_kNativeLang) ?? 'en',
      targetLangCode: prefs.getString(_kTargetLang) ?? 'es',
    );
  }

  Future<void> saveConfig(AiEngineConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kProvider, config.provider.index);
    await prefs.setString(_kApiKey, config.apiKey);
    await prefs.setString(_kModelId, config.modelId);
    await prefs.setString(_kCustomEndpoint, config.customEndpoint);
    await prefs.setInt(_kPauseMs, config.pauseThresholdMs);
    await prefs.setDouble(_kWhisperVol, config.whisperVolume);
    await prefs.setString(_kNativeLang, config.nativeLangCode);
    await prefs.setString(_kTargetLang, config.targetLangCode);
  }
}
