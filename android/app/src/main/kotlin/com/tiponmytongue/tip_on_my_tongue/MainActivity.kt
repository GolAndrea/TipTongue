package com.tiponmytongue.tip_on_my_tongue

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.tiponmytongue/glasses"
    private val eventsChannelName = "com.tiponmytongue/glasses_events"
    private var datBridge: DatGlassesBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bridge = DatGlassesBridge(applicationContext).also {
            it.ensureInitialized()
            datBridge = it
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventsChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    bridge.attachEventSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    bridge.attachEventSink(null)
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "scanBluetoothAudioDevices" -> {
                        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_ALL)
                        val btList = mutableListOf<Map<String, Any>>()
                        val seenNames = mutableSetOf<String>()
                        for (d in devices) {
                            val isBt = d.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                                d.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                                    d.type == AudioDeviceInfo.TYPE_BLE_HEADSET)
                            if (isBt) {
                                val name = d.productName?.toString()?.trim().orEmpty()
                                if (name.isNotEmpty() && seenNames.add(name)) {
                                    btList.add(
                                        mapOf(
                                            "id" to "bt_${d.id}",
                                            "name" to name,
                                            "hasMic" to d.isSource,
                                        )
                                    )
                                }
                            }
                        }
                        result.success(btList)
                    }
                    "setHfpRouting" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        try {
                            if (enabled) {
                                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    val target = audioManager.availableCommunicationDevices.firstOrNull {
                                        it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                                            it.type == AudioDeviceInfo.TYPE_BLE_HEADSET
                                    }
                                    if (target != null) {
                                        audioManager.setCommunicationDevice(target)
                                    }
                                } else {
                                    @Suppress("DEPRECATION")
                                    audioManager.startBluetoothSco()
                                    @Suppress("DEPRECATION")
                                    audioManager.isBluetoothScoOn = true
                                }
                            } else {
                                // Release HFP back to high-fidelity A2DP for notebook replay.
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    audioManager.clearCommunicationDevice()
                                } else {
                                    @Suppress("DEPRECATION")
                                    audioManager.stopBluetoothSco()
                                    @Suppress("DEPRECATION")
                                    audioManager.isBluetoothScoOn = false
                                }
                                audioManager.mode = AudioManager.MODE_NORMAL
                            }
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "getDatStatus" -> result.success(bridge.buildTelemetryMap())
                    "startDatRegistration" -> result.success(bridge.startRegistration(this))
                    "enableMockDisplayDevice" -> result.success(bridge.enableMockDisplayDevice())
                    "disableMockDisplayDevice" -> result.success(bridge.disableMockDisplayDevice())
                    "pushDisplayWord" -> {
                        val word = call.argument<String>("word").orEmpty()
                        val meaning = call.argument<String>("meaningHint").orEmpty()
                        val languagePair = call.argument<String>("languagePair").orEmpty()
                        result.success(bridge.pushDisplayWord(word, meaning, languagePair))
                    }
                    "clearDisplayHud" -> result.success(bridge.clearDisplayHud())
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        datBridge?.dispose()
        datBridge = null
        super.onDestroy()
    }
}
