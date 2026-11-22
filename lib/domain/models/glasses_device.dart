enum GlassesGeneration {
  standalonePhone,
  rayBanMetaGen1,
  rayBanMetaGen2,
  rayBanMetaAudio,
  rayBanMetaDisplay,
}

/// Live hardware telemetry mirrored from Meta Wearables DAT v1.0 DeviceState
/// (donState, hingeState, batteryLevel, chargingState, thermalLevel).
class GlassesDeviceTelemetry {
  const GlassesDeviceTelemetry({
    this.isDonned = true,
    this.isHingeOpen = true,
    this.batteryLevel,
    this.isCharging = false,
    this.thermalLevel = 'nominal',
    this.datAvailable = false,
    this.datSdkVersion = '1.0.1',
    this.datRegistrationState = 'unavailable',
    this.isOfficialMockActive = false,
    this.isDisplayAttached = false,
    this.chromePreviewUrl,
  });

  final bool isDonned;
  final bool isHingeOpen;
  final int? batteryLevel;
  final bool isCharging;
  final String thermalLevel;
  final bool datAvailable;
  final String datSdkVersion;
  final String datRegistrationState;
  final bool isOfficialMockActive;
  final bool isDisplayAttached;
  final String? chromePreviewUrl;

  bool get shouldAutoPause => !isDonned || !isHingeOpen;

  bool get isLowBattery => batteryLevel != null && batteryLevel! < 15 && !isCharging;

  bool get isThermallyConstrained {
    final t = thermalLevel.toLowerCase();
    return t == 'severe' || t == 'critical' || t == 'serious';
  }

  GlassesDeviceTelemetry copyWith({
    bool? isDonned,
    bool? isHingeOpen,
    int? batteryLevel,
    bool? isCharging,
    String? thermalLevel,
    bool? datAvailable,
    String? datSdkVersion,
    String? datRegistrationState,
    bool? isOfficialMockActive,
    bool? isDisplayAttached,
    String? chromePreviewUrl,
  }) {
    return GlassesDeviceTelemetry(
      isDonned: isDonned ?? this.isDonned,
      isHingeOpen: isHingeOpen ?? this.isHingeOpen,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      thermalLevel: thermalLevel ?? this.thermalLevel,
      datAvailable: datAvailable ?? this.datAvailable,
      datSdkVersion: datSdkVersion ?? this.datSdkVersion,
      datRegistrationState: datRegistrationState ?? this.datRegistrationState,
      isOfficialMockActive: isOfficialMockActive ?? this.isOfficialMockActive,
      isDisplayAttached: isDisplayAttached ?? this.isDisplayAttached,
      chromePreviewUrl: chromePreviewUrl ?? this.chromePreviewUrl,
    );
  }

  factory GlassesDeviceTelemetry.fromMap(Map<String, dynamic> map) {
    final rawBattery = map['batteryLevel'];
    return GlassesDeviceTelemetry(
      isDonned: (map['isDonned'] as bool?) ?? true,
      isHingeOpen: (map['isHingeOpen'] as bool?) ?? true,
      batteryLevel: rawBattery is num ? rawBattery.toInt() : null,
      isCharging: (map['isCharging'] as bool?) ?? false,
      thermalLevel: (map['thermalLevel'] as String?) ?? 'nominal',
      datAvailable: (map['datAvailable'] as bool?) ?? false,
      datSdkVersion: (map['datSdkVersion'] as String?) ?? '1.0.1',
      datRegistrationState:
          (map['datRegistrationState'] as String?) ?? 'unavailable',
      isOfficialMockActive: (map['isOfficialMockActive'] as bool?) ?? false,
      isDisplayAttached: (map['isDisplayAttached'] as bool?) ?? false,
      chromePreviewUrl: map['chromePreviewUrl'] as String?,
    );
  }
}

class GlassesDevice {
  const GlassesDevice({
    required this.id,
    required this.name,
    required this.generation,
    required this.isSimulated,
  });

  final String id;
  final String name;
  final GlassesGeneration generation;
  final bool isSimulated;

  /// Only Meta Ray-Ban Display has an in-lens waveguide HUD (600x600).
  /// Gen 1, Gen 2, and Ray-Ban Meta Audio are screenless audio-only output.
  bool get supportsDisplay =>
      generation == GlassesGeneration.rayBanMetaDisplay;

  /// Camera and hardware LED are strictly kept OFF in all generations
  /// (mwdat-camera / NSCameraUsageDescription / CAMERA are omitted).
  bool get isCameraForcedOff => true;

  bool get recommendedHudEnabled => supportsDisplay;

  /// Audio-only glasses require Whisper ON; Display defaults to HUD-first
  /// with optional Whisper toggle for noisy outdoor environments.
  bool get recommendedWhisperEnabled => !supportsDisplay;

  String get stripLabel {
    switch (generation) {
      case GlassesGeneration.standalonePhone:
        return 'Phone & Earbuds';
      case GlassesGeneration.rayBanMetaGen1:
        return 'Ray-Ban Meta Gen 1';
      case GlassesGeneration.rayBanMetaGen2:
        return 'Ray-Ban Meta Gen 2';
      case GlassesGeneration.rayBanMetaAudio:
        return 'Ray-Ban Meta Audio';
      case GlassesGeneration.rayBanMetaDisplay:
        return 'Meta Ray-Ban Display';
    }
  }

  String get deviceCategoryLabel {
    switch (generation) {
      case GlassesGeneration.standalonePhone:
        return 'Phone & Earbuds';
      case GlassesGeneration.rayBanMetaGen1:
      case GlassesGeneration.rayBanMetaGen2:
      case GlassesGeneration.rayBanMetaAudio:
        return 'Audio glasses';
      case GlassesGeneration.rayBanMetaDisplay:
        return 'Display glasses';
    }
  }

  String get lensChannelNote {
    switch (generation) {
      case GlassesGeneration.standalonePhone:
        return 'Shown on\nscreen';
      case GlassesGeneration.rayBanMetaGen1:
      case GlassesGeneration.rayBanMetaGen2:
      case GlassesGeneration.rayBanMetaAudio:
        return 'Whispered\nin ear';
      case GlassesGeneration.rayBanMetaDisplay:
        return 'Shown on\nright lens';
    }
  }

  String get usageNotificationTitle {
    switch (generation) {
      case GlassesGeneration.standalonePhone:
        return 'Phone & Earbuds';
      case GlassesGeneration.rayBanMetaGen1:
        return 'Ray-Ban Meta Gen 1 · Audio glasses';
      case GlassesGeneration.rayBanMetaGen2:
        return 'Ray-Ban Meta Gen 2 · Audio glasses';
      case GlassesGeneration.rayBanMetaAudio:
        return 'Ray-Ban Meta Audio · Audio glasses';
      case GlassesGeneration.rayBanMetaDisplay:
        return 'Meta Ray-Ban Display · Display glasses';
    }
  }

  String get usageNotificationBody {
    switch (generation) {
      case GlassesGeneration.standalonePhone:
        return 'Phone & Earbuds — shows the word on screen or whispers it softly. Camera and unused sensors stay off; live audio is automatically erased after 30 seconds.';
      case GlassesGeneration.rayBanMetaGen1:
      case GlassesGeneration.rayBanMetaGen2:
      case GlassesGeneration.rayBanMetaAudio:
        return 'Audio glasses — whispers the missing word softly in your ear. Camera and recording LED are never used; live audio is automatically erased after 30 seconds.';
      case GlassesGeneration.rayBanMetaDisplay:
        return 'Display glasses — shows the missing word on the lens, with optional whisper audio. Camera and recording LED are never used; live audio is automatically erased after 30 seconds.';
    }
  }

  static GlassesDevice standalone() => const GlassesDevice(
        id: 'local_phone',
        name: 'Phone & Earbuds',
        generation: GlassesGeneration.standalonePhone,
        isSimulated: false,
      );

  static List<GlassesDevice> simulatedCatalog() => const [
        GlassesDevice(
          id: 'sim_rb_gen1',
          name: 'Ray-Ban Meta (Gen 1)',
          generation: GlassesGeneration.rayBanMetaGen1,
          isSimulated: true,
        ),
        GlassesDevice(
          id: 'sim_rb_gen2',
          name: 'Ray-Ban Meta (Gen 2)',
          generation: GlassesGeneration.rayBanMetaGen2,
          isSimulated: true,
        ),
        GlassesDevice(
          id: 'sim_rb_audio',
          name: 'Ray-Ban Meta Audio',
          generation: GlassesGeneration.rayBanMetaAudio,
          isSimulated: true,
        ),
        GlassesDevice(
          id: 'sim_rb_display',
          name: 'Meta Ray-Ban Display',
          generation: GlassesGeneration.rayBanMetaDisplay,
          isSimulated: true,
        ),
      ];

  static GlassesDevice fromBluetoothDevice({
    required String id,
    required String rawName,
  }) {
    final lower = rawName.toLowerCase();
    final GlassesGeneration gen;
    if (lower.contains('display') || lower.contains('hypernova')) {
      gen = GlassesGeneration.rayBanMetaDisplay;
    } else if (lower.contains('meta audio') || lower.contains('ray-ban audio')) {
      gen = GlassesGeneration.rayBanMetaAudio;
    } else if (lower.contains('gen 2') ||
        lower.contains('gen2') ||
        lower.contains('gen 3') ||
        lower.contains('gen3')) {
      gen = GlassesGeneration.rayBanMetaGen2;
    } else if (lower.contains('ray-ban') ||
        lower.contains('rayban') ||
        lower.contains('meta') ||
        lower.contains('oakley')) {
      gen = GlassesGeneration.rayBanMetaGen1;
    } else {
      gen = GlassesGeneration.standalonePhone;
    }
    return GlassesDevice(
      id: id,
      name: rawName,
      generation: gen,
      isSimulated: false,
    );
  }
}
