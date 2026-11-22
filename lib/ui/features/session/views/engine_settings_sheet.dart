import 'package:flutter/material.dart';

import '../../../../domain/models/ai_engine_config.dart';
import '../../../core/app_theme.dart';
import '../view_models/session_view_model.dart';

class EngineSettingsSheet extends StatefulWidget {
  const EngineSettingsSheet({super.key, required this.viewModel});

  final SessionViewModel viewModel;

  @override
  State<EngineSettingsSheet> createState() => _EngineSettingsSheetState();
}

class _EngineSettingsSheetState extends State<EngineSettingsSheet> {
  late AiProviderType _provider;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _endpointCtrl;
  late double _whisperVol;

  @override
  void initState() {
    super.initState();
    final cfg = widget.viewModel.config;
    _provider = cfg.provider;
    _apiKeyCtrl = TextEditingController(text: cfg.apiKey);
    _modelCtrl = TextEditingController(text: cfg.modelId);
    _endpointCtrl = TextEditingController(text: cfg.customEndpoint);
    _whisperVol = cfg.whisperVolume;
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _endpointCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = widget.viewModel.config.copyWith(
      provider: _provider,
      apiKey: _apiKeyCtrl.text.trim(),
      modelId: _modelCtrl.text.trim().isEmpty
          ? _provider.defaultModel
          : _modelCtrl.text.trim(),
      customEndpoint: _endpointCtrl.text.trim(),
      whisperVolume: _whisperVol,
    );
    await widget.viewModel.updateConfig(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'AI Engine & Audio',
                style: TextStyle(
                  fontFamily: AppTheme.fontSerif,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Works in any environment — the model infers context directly from your unfinished sentence using fast, lightweight LLMs (< 2 s pause budget). Leave API key blank for offline fallback.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.inkMuted),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AiProviderType>(
                initialValue: _provider,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Free AI Provider',
                  isDense: true,
                ),
                items: AiProviderType.values
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                          p.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _provider = val;
                    _modelCtrl.text = val.defaultModel;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_provider != AiProviderType.offlineDemo) ...[
                TextField(
                  controller: _modelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Model ID (editable for future upgrades)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_provider == AiProviderType.customOpenAi) ...[
                TextField(
                  controller: _endpointCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Endpoint URL (e.g. Ollama / vLLM)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_provider.requiresApiKey) ...[
                TextField(
                  controller: _apiKeyCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Free API Key (${_provider.name})',
                    hintText: 'Leave blank for local contextual fallback',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Whisper audio volume',
                    style: TextStyle(fontSize: 13, color: AppTheme.inkPrimary),
                  ),
                  Text(
                    '${(_whisperVol * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.accentTerracotta,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _whisperVol,
                min: 0.05,
                max: 0.80,
                divisions: 15,
                onChanged: (v) => setState(() => _whisperVol = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentTerracotta,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save changes',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
