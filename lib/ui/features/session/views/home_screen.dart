import 'package:flutter/material.dart';

import '../../../../domain/models/ai_engine_config.dart';
import '../../../core/app_theme.dart';
import '../view_models/session_view_model.dart';
import 'engine_settings_sheet.dart';
import 'glasses_sheet.dart';
import 'hud_lens_preview.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.viewModel});

  final SessionViewModel viewModel;

  void _openGlassesSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgWarmPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => GlassesConnectionSheet(viewModel: viewModel),
    );
  }

  void _openEngineSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgWarmPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EngineSettingsSheet(viewModel: viewModel),
    );
  }

  void _openLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgWarmPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LanguagePairSheet(viewModel: viewModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final dev = viewModel.connectedDevice;
        final nativeLang =
            SupportedLanguage.byCode(viewModel.config.nativeLangCode);
        final targetLang =
            SupportedLanguage.byCode(viewModel.config.targetLangCode);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Editorial Header with Hairline Rule
                  Container(
                    padding: const EdgeInsets.only(bottom: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppTheme.borderRule),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'TipTongue',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontSerif,
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                              color: AppTheme.inkPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(99),
                          onTap: () => _openLanguageSheet(context),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 196),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceStrip,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${nativeLang.shortBadge} → ${targetLang.name} · ${SupportedLanguage.all.length}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.accentTerracotta,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'AI Engine & Audio Settings',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _openEngineSheet(context),
                          icon: const Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: AppTheme.inkBody,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Editorial Notebook Body
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        // 2. Central Notebook Sheet + Lens Focus Card (Hero right at the top)
                        HudLensPreview(
                          device: dev,
                          liveTranscript: viewModel.liveTranscript,
                          targetLanguageName: targetLang.name,
                          activeSuggestion: viewModel.activeSuggestion,
                          isPredicting: viewModel.isPredicting,
                          isSessionActive: viewModel.isSessionActive,
                          silenceMs: viewModel.currentSilenceMs,
                          thresholdMs: viewModel.config.pauseThresholdMs,
                        ),
                        const SizedBox(height: 22),

                        // 3. Personal Notebook · Today
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Flexible(
                              child: Text(
                                'Personal notebook · Today',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.inkMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${viewModel.recentSuggestions.length} '
                              '${viewModel.recentSuggestions.length == 1 ? 'word' : 'words'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.inkMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (viewModel.recentSuggestions.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceSheet,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: AppTheme.borderCard),
                            ),
                            child: const Text(
                              'Words rescued when you pause mid-sentence will gather here for review.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.inkMuted,
                                height: 1.4,
                              ),
                            ),
                          )
                        else
                          ...viewModel.recentSuggestions.take(5).map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color: AppTheme.surfaceSheet,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(11),
                                      side: const BorderSide(
                                        color: AppTheme.borderCard,
                                      ),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(11),
                                      onTap: () =>
                                          viewModel.replayWordWhisper(s.word),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 11,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              s.word,
                                              style: const TextStyle(
                                                fontFamily: AppTheme.fontSerif,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: AppTheme.inkPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                s.meaningHint.isNotEmpty
                                                    ? s.meaningHint
                                                    : 'Tap to hear pronunciation',
                                                textAlign: TextAlign.right,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: AppTheme.inkMuted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),

                  // 4. Moved Device & Privacy Link (Quiet footer above main CTA)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: AppTheme.surfaceStrip,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openGlassesSheet(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      viewModel.telemetry.batteryLevel != null
                                          ? '${dev.stripLabel} · ${viewModel.telemetry.batteryLevel}%'
                                          : dev.stripLabel,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.inkBody,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Device & privacy',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.inkMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: AppTheme.inkMuted,
                                  ),
                                ],
                              ),
                              if (viewModel.autoPausedByGlassesState &&
                                  viewModel.statusMessage != null) ...[
                                const SizedBox(height: 5),
                                Text(
                                  viewModel.statusMessage!,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accentTerracotta,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 6. Bottom Primary Editorial Terracotta CTA
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accentTerracotta,
                        foregroundColor: AppTheme.surfaceSheet,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      onPressed: viewModel.toggleLiveSession,
                      icon: Icon(
                        viewModel.isSessionActive
                            ? Icons.pause_circle_filled_rounded
                            : Icons.mic_rounded,
                        size: 20,
                      ),
                      label: Text(
                        viewModel.isSessionActive
                            ? 'Session active · Tap to pause'
                            : 'Start speaking in ${targetLang.name}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LanguagePairSheet extends StatefulWidget {
  const _LanguagePairSheet({required this.viewModel});

  final SessionViewModel viewModel;

  @override
  State<_LanguagePairSheet> createState() => _LanguagePairSheetState();
}

class _LanguagePairSheetState extends State<_LanguagePairSheet> {
  final TextEditingController _searchController = TextEditingController();
  bool _pickingTarget = true;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final nativeLang =
            SupportedLanguage.byCode(widget.viewModel.config.nativeLangCode);
        final targetLang =
            SupportedLanguage.byCode(widget.viewModel.config.targetLangCode);
        final matches = SupportedLanguage.search(_query);
        final selectedCode =
            _pickingTarget ? targetLang.code : nativeLang.code;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Languages',
                        style: TextStyle(
                          fontFamily: AppTheme.fontSerif,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.inkPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentSage.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${SupportedLanguage.all.length} supported',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentSage,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _LanguageRoleTab(
                        label: 'Speaking',
                        value: targetLang.name,
                        selected: _pickingTarget,
                        onTap: () => setState(() => _pickingTarget = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LanguageRoleTab(
                        label: 'Base',
                        value: nativeLang.name,
                        selected: !_pickingTarget,
                        onTap: () => setState(() => _pickingTarget = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search 24 languages (e.g. Finnish, Japanese, ES)…',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 256,
                  child: matches.isEmpty
                      ? Center(
                          child: Text(
                            'No language matching "$_query" among the ${SupportedLanguage.all.length} presets.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.inkMuted,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: matches.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (_, index) {
                            final lang = matches[index];
                            final isSelected = lang.code == selectedCode;
                            final subtitle = lang.name == lang.englishName
                                ? lang.localeId
                                : '${lang.englishName} · ${lang.localeId}';

                            return Material(
                              color: isSelected
                                  ? AppTheme.surfaceStrip
                                  : AppTheme.surfaceSheet,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                                side: BorderSide(
                                  color: isSelected
                                      ? AppTheme.accentTerracotta
                                      : AppTheme.borderCard,
                                  width: isSelected ? 1.4 : 1.0,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(11),
                                onTap: () {
                                  if (_pickingTarget) {
                                    widget.viewModel.updateConfig(
                                      widget.viewModel.config.copyWith(
                                        targetLangCode: lang.code,
                                      ),
                                    );
                                  } else {
                                    widget.viewModel.updateConfig(
                                      widget.viewModel.config.copyWith(
                                        nativeLangCode: lang.code,
                                      ),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceStrip,
                                          borderRadius:
                                              BorderRadius.circular(7),
                                        ),
                                        child: Text(
                                          lang.shortBadge,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.accentTerracotta,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lang.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.inkPrimary,
                                              ),
                                            ),
                                            Text(
                                              subtitle,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppTheme.inkMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 20,
                                          color: AppTheme.accentTerracotta,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accentTerracotta,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LanguageRoleTab extends StatelessWidget {
  const _LanguageRoleTab({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.inkPrimary : AppTheme.surfaceSheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(
          color: selected ? AppTheme.inkPrimary : AppTheme.borderCard,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppTheme.surfaceStrip : AppTheme.inkMuted,
                ),
              ),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppTheme.bgWarmPaper : AppTheme.inkPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
