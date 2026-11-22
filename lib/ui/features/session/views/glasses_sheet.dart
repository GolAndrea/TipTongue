import 'package:flutter/material.dart';

import '../../../../domain/models/glasses_device.dart';
import '../../../core/app_theme.dart';
import '../view_models/session_view_model.dart';

class GlassesConnectionSheet extends StatelessWidget {
  const GlassesConnectionSheet({super.key, required this.viewModel});

  final SessionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final current = viewModel.connectedDevice;
        final canToggleWhisper = current.supportsDisplay ||
            current.generation == GlassesGeneration.standalonePhone;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Device & Privacy',
                          style: TextStyle(
                            fontFamily: AppTheme.fontSerif,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.inkPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentSage.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam_off_outlined,
                              size: 14,
                              color: AppTheme.accentSage,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Camera off',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.accentSage,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceStrip,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current.usageNotificationTitle,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Camera and unused sensors are never accessed. Live audio is never saved and is automatically erased after 30 seconds.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: AppTheme.inkBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canToggleWhisper) ...[
                    const SizedBox(height: 6),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeTrackColor: AppTheme.accentSage,
                      title: const Text(
                        'Whisper audio prompt',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.inkPrimary,
                        ),
                      ),
                      subtitle: Text(
                        current.supportsDisplay
                            ? 'Optional on display glasses (helpful in noisy places)'
                            : 'Speaks the rescued word softly',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.inkMuted,
                        ),
                      ),
                      value: viewModel.whisperEnabled,
                      onChanged: viewModel.toggleWhisper,
                    ),
                  ],
                  if (viewModel.telemetry.datAvailable) ...[
                    const Divider(height: 22),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: viewModel.startDatRegistration,
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: const Text('Connect via Meta AI'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              viewModel.toggleOfficialMockDisplay(
                            !viewModel.telemetry.isOfficialMockActive,
                          ),
                          icon: Icon(
                            viewModel.telemetry.isOfficialMockActive
                                ? Icons.developer_mode_rounded
                                : Icons.smart_display_outlined,
                            size: 16,
                          ),
                          label: Text(
                            viewModel.telemetry.isOfficialMockActive
                                ? 'Stop preview glasses'
                                : 'Preview Display glasses',
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Paired glasses',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: viewModel.isScanningGlasses
                            ? null
                            : viewModel.scanForRealGlasses,
                        icon: viewModel.isScanningGlasses
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bluetooth_searching, size: 17),
                        label: const Text('Scan'),
                      ),
                    ],
                  ),
                  if (viewModel.discoveredBluetoothDevices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'No glasses paired via Bluetooth right now.',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.inkMuted),
                      ),
                    )
                  else
                    ...viewModel.discoveredBluetoothDevices.map(
                      (dev) => _DeviceTile(
                        device: dev,
                        selected: current.id == dev.id,
                        onTap: () {
                          viewModel.selectGlassesDevice(dev);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  const Divider(height: 22),
                  const Text(
                    'Device type',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DeviceTile(
                    device: GlassesDevice.standalone(),
                    selected: current.id == 'local_phone',
                    onTap: () {
                      viewModel.selectGlassesDevice(GlassesDevice.standalone());
                      Navigator.of(context).pop();
                    },
                  ),
                  ...viewModel.simulatedDevices.map(
                    (dev) => _DeviceTile(
                      device: dev,
                      selected: current.id == dev.id,
                      onTap: () {
                        viewModel.selectGlassesDevice(dev);
                        Navigator.of(context).pop();
                      },
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

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.selected,
    required this.onTap,
  });

  final GlassesDevice device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = device.generation == GlassesGeneration.standalonePhone
        ? 'On-screen prompt & soft audio'
        : device.supportsDisplay
            ? 'Display glasses · Word on lens'
            : 'Audio glasses · Quiet whisper';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppTheme.surfaceStrip : AppTheme.surfaceSheet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppTheme.accentTerracotta : AppTheme.borderCard,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          dense: true,
          leading: Icon(
            device.supportsDisplay
                ? Icons.visibility_outlined
                : device.generation == GlassesGeneration.standalonePhone
                    ? Icons.smartphone_rounded
                    : Icons.headphones_outlined,
            color: selected ? AppTheme.accentTerracotta : AppTheme.inkMuted,
          ),
          title: Text(
            device.name,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: AppTheme.inkPrimary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppTheme.inkMuted),
          ),
          trailing: selected
              ? const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accentTerracotta,
                )
              : null,
        ),
      ),
    );
  }
}
