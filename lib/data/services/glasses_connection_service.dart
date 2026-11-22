import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/models/glasses_device.dart';

/// Cross-platform bridge (Android DAT v1.0.1 + iOS HFP/DAT hooks + Web/Simulator)
/// for Ray-Ban Meta glasses.
/// Camera modules (mwdat-camera / MWDATCamera) are intentionally excluded so the
/// hardware camera and privacy LED remain OFF on every generation.
class GlassesConnectionService {
  static const MethodChannel _channel =
      MethodChannel('com.tiponmytongue/glasses');
  static const EventChannel _eventsChannel =
      EventChannel('com.tiponmytongue/glasses_events');

  Stream<GlassesDeviceTelemetry> get telemetryStream {
    if (kIsWeb) return const Stream<GlassesDeviceTelemetry>.empty();
    try {
      return _eventsChannel.receiveBroadcastStream().map((dynamic event) {
        if (event is Map) {
          return GlassesDeviceTelemetry.fromMap(
            Map<String, dynamic>.from(event),
          );
        }
        return const GlassesDeviceTelemetry();
      }).handleError((Object _) {});
    } catch (_) {
      return const Stream<GlassesDeviceTelemetry>.empty();
    }
  }

  Future<List<GlassesDevice>> scanRealBluetoothGlasses() async {
    if (kIsWeb) return const [];
    try {
      final rawList = await _channel
          .invokeMethod<List<dynamic>>('scanBluetoothAudioDevices');
      if (rawList == null) return const [];

      return rawList.map((entry) {
        final map = Map<String, dynamic>.from(entry as Map);
        return GlassesDevice.fromBluetoothDevice(
          id: (map['id'] as String?) ?? 'bt_unknown',
          rawName: (map['name'] as String?) ?? 'Bluetooth Audio',
        );
      }).toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Switches audio routing between Bluetooth HFP (beamforming wearer mic
  /// during active live conversation) and A2DP (high-fidelity open-ear audio
  /// when replaying saved notebook words while idle).
  Future<void> setGlassesAudioRouting(bool hfpEnabled) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<bool>(
        'setHfpRouting',
        {'enabled': hfpEnabled},
      );
    } catch (_) {
      // Safe fallback on unsupported desktop/web platforms.
    }
  }

  /// Queries native Meta Wearables DAT v1.0.1 availability, registration state,
  /// mock device status, and live DeviceState snapshot.
  Future<GlassesDeviceTelemetry> getDatStatus() async {
    if (kIsWeb) return const GlassesDeviceTelemetry();
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getDatStatus',
      );
      if (raw == null) return const GlassesDeviceTelemetry();
      return GlassesDeviceTelemetry.fromMap(Map<String, dynamic>.from(raw));
    } catch (_) {
      return const GlassesDeviceTelemetry();
    }
  }

  /// Initiates Meta AI registration flow via Wearables.startRegistration(activity).
  Future<bool> startDatRegistration() async {
    if (kIsWeb) return false;
    try {
      return (await _channel.invokeMethod<bool>('startDatRegistration')) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Toggles official Meta DAT MockDeviceKit (GlassesModel.META_RAYBAN_DISPLAY)
  /// so Display rendering & DeviceState can be exercised without physical frames.
  Future<GlassesDeviceTelemetry> setOfficialMockDisplay(bool enabled) async {
    if (kIsWeb) return const GlassesDeviceTelemetry();
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        enabled ? 'enableMockDisplayDevice' : 'disableMockDisplayDevice',
      );
      if (raw == null) return const GlassesDeviceTelemetry();
      return GlassesDeviceTelemetry.fromMap(Map<String, dynamic>.from(raw));
    } catch (_) {
      return const GlassesDeviceTelemetry();
    }
  }

  /// Pushes a single rescued word onto Meta Ray-Ban Display optics via
  /// mwdat-display / MWDATDisplay (no-op on screenless frames or Web).
  Future<bool> pushDisplayWord({
    required String word,
    required String meaningHint,
    required String languagePair,
  }) async {
    if (kIsWeb) return false;
    try {
      return (await _channel.invokeMethod<bool>('pushDisplayWord', {
            'word': word,
            'meaningHint': meaningHint,
            'languagePair': languagePair,
          })) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Clears the peripheral optical lens card when speech resumes or times out.
  Future<void> clearDisplayHud() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<bool>('clearDisplayHud');
    } catch (_) {}
  }

  List<GlassesDevice> getSimulatedModels() => GlassesDevice.simulatedCatalog();
}
