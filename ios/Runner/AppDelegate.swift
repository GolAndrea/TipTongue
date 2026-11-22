import AVFoundation
import Flutter
import UIKit

#if canImport(MWDATCore)
import MWDATCore
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.tiponmytongue/glasses",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      let session = AVAudioSession.sharedInstance()
      switch call.method {
      case "scanBluetoothAudioDevices":
        var btList: [[String: Any]] = []
        var seen = Set<String>()
        let ports = (session.availableInputs ?? []) + session.currentRoute.outputs
        for port in ports {
          let isBt =
            port.portType == .bluetoothHFP ||
            port.portType == .bluetoothA2DP ||
            port.portType == .bluetoothLE
          if isBt && !seen.contains(port.portName) {
            seen.insert(port.portName)
            btList.append([
              "id": port.uid,
              "name": port.portName,
              "hasMic": port.portType == .bluetoothHFP || port.portType == .bluetoothLE,
            ])
          }
        }
        result(btList)
      case "setHfpRouting":
        let args = call.arguments as? [String: Any]
        let enabled = args?["enabled"] as? Bool ?? false
        do {
          if enabled {
            // HFP beamforming microphone during active conversation
            try session.setCategory(
              .playAndRecord,
              mode: .voiceChat,
              options: [.allowBluetooth, .defaultToSpeaker]
            )
            try session.setActive(true)
          } else {
            // Release HFP back to high-fidelity A2DP for notebook playback
            try session.setCategory(
              .playback,
              mode: .default,
              options: [.allowBluetoothA2DP]
            )
            try session.setActive(true)
          }
          result(true)
        } catch {
          result(false)
        }
      case "getDatStatus":
        #if canImport(MWDATCore)
        let datAvailable = true
        #else
        let datAvailable = false
        #endif
        result([
          "datAvailable": datAvailable,
          "datSdkVersion": "1.0.1",
          "datRegistrationState": datAvailable ? "available" : "unavailable",
          "isOfficialMockActive": false,
          "isDisplayAttached": false,
          "isDonned": true,
          "isHingeOpen": true,
          "isCharging": false,
          "thermalLevel": "nominal",
        ])
      case "startDatRegistration", "enableMockDisplayDevice", "disableMockDisplayDevice",
           "pushDisplayWord", "clearDisplayHud":
        result(false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
