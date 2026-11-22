import 'package:flutter/material.dart';

import '../../../../domain/models/ai_engine_config.dart';
import '../../../../domain/models/glasses_device.dart';
import '../../../core/app_theme.dart';

/// Editorial Notebook Sheet: pairs the left-ruled spoken utterance + pause badge
/// with the dark optical 600x600 right-lens / HFP whisper focus block.
class HudLensPreview extends StatelessWidget {
  const HudLensPreview({
    super.key,
    required this.device,
    required this.liveTranscript,
    required this.targetLanguageName,
    required this.activeSuggestion,
    required this.isPredicting,
    required this.isSessionActive,
    required this.silenceMs,
    required this.thresholdMs,
  });

  final GlassesDevice device;
  final String liveTranscript;
  final String targetLanguageName;
  final WordSuggestion? activeSuggestion;
  final bool isPredicting;
  final bool isSessionActive;
  final int silenceMs;
  final int thresholdMs;

  @override
  Widget build(BuildContext context) {
    final bool hasVisualLens = device.supportsDisplay ||
        device.generation == GlassesGeneration.standalonePhone;
    final double progress =
        thresholdMs > 0 ? (silenceMs / thresholdMs).clamp(0.0, 1.0) : 0.0;

    final int badgeMs = activeSuggestion != null
        ? activeSuggestion!.pauseDurationMs
        : silenceMs;
    final String pauseLabel =
        '${(badgeMs / 1000).toStringAsFixed(1)}s pause';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSheet,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderCard),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D241C15),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Left-ruled Dialogue Quote + Pause Badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 14),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFFD5C5AE), width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  liveTranscript.isEmpty
                      ? (isSessionActive
                          ? 'Listening in $targetLanguageName… speak naturally and pause if a word slips your mind.'
                          : 'Tap below to begin speaking in $targetLanguageName. Pause mid-sentence to surface the missing word.')
                      : '“$liveTranscript…',
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.5,
                    color: liveTranscript.isEmpty
                        ? AppTheme.inkMuted
                        : AppTheme.inkBody,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (badgeMs > 0 || activeSuggestion != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.pauseBadgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pauseLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentTerracotta,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Dark Optical Focus Window (HUD 600x600 / Whisper Output)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: AppTheme.lensFocusBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: isPredicting
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.lensAmberWord,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      'Finding word…',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.lensSubtleText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : activeSuggestion != null
                              ? Text(
                                  activeSuggestion!.word,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontSerif,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 40,
                                    height: 1.08,
                                    color: AppTheme.lensAmberWord,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hasVisualLens
                                          ? 'Lens clear'
                                          : 'Audio whisper ready',
                                      style: const TextStyle(
                                        fontFamily: AppTheme.fontSerif,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 24,
                                        color: Color(0xFF8C7B6B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      hasVisualLens
                                          ? 'Waiting for a mid-phrase pause'
                                          : 'Waiting for a mid-phrase pause · Quiet whisper ready',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppTheme.lensRightNote,
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      device.lensChannelNote,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppTheme.lensRightNote,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (isSessionActive) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: const Color(0xFF2F261F),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 0.85
                            ? AppTheme.lensAmberWord
                            : AppTheme.accentTerracotta,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
