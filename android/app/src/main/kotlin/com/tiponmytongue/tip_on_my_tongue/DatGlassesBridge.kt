package com.tiponmytongue.tip_on_my_tongue

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import com.meta.wearable.dat.core.selectors.SpecificDeviceSelector
import com.meta.wearable.dat.core.session.DeviceSession
import com.meta.wearable.dat.core.session.DeviceSessionState
import com.meta.wearable.dat.core.types.Device
import com.meta.wearable.dat.core.types.DeviceIdentifier
import com.meta.wearable.dat.core.types.RegistrationState
import com.meta.wearable.dat.display.Display
import com.meta.wearable.dat.display.addDisplay
import com.meta.wearable.dat.display.removeDisplay
import com.meta.wearable.dat.display.types.DisplayState
import com.meta.wearable.dat.display.views.Alignment
import com.meta.wearable.dat.display.views.ButtonStyle
import com.meta.wearable.dat.display.views.Direction
import com.meta.wearable.dat.display.views.FlexBoxBackground
import com.meta.wearable.dat.display.views.TextColor
import com.meta.wearable.dat.display.views.TextStyle
import com.meta.wearable.dat.mockdevice.MockDeviceKit
import com.meta.wearable.dat.mockdevice.api.GlassesModel
import com.meta.wearable.dat.mockdevice.api.MockGlasses
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Native Android bridge to the official Meta Wearables Device Access Toolkit (DAT v1.0.1).
 *
 * Uses mwdat-core + mwdat-display + mwdat-mockdevice only.
 * mwdat-camera is intentionally omitted so hardware camera & privacy LED remain 100% OFF.
 */
class DatGlassesBridge(private val appContext: Context) {
    companion object {
        private const val TAG = "TipTongueDatBridge"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val exceptionHandler = CoroutineExceptionHandler { _, throwable ->
        Log.w(TAG, "DAT coroutine error: ${throwable.message}")
    }

    private var eventSink: EventChannel.EventSink? = null
    private var initialized = false
    private var registrationState: RegistrationState = RegistrationState.UNAVAILABLE
    private var latestDevice: Device? = null
    private var mockGlasses: MockGlasses? = null
    private var mockDeviceId: DeviceIdentifier? = null
    private var chromePreviewUrl: String? = null

    private var session: DeviceSession? = null
    private var display: Display? = null
    private var displayReady = false
    private var pendingWord: Triple<String, String, String>? = null
    private val metadataJobs = mutableMapOf<DeviceIdentifier, Job>()

    fun attachEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        if (sink != null) {
            emitTelemetrySnapshot()
        }
    }

    fun ensureInitialized() {
        if (initialized) return
        try {
            Wearables.initialize(appContext)
            initialized = true
            startObserving()
        } catch (e: Throwable) {
            Log.w(TAG, "Wearables.initialize deferred or unavailable: ${e.message}")
        }
    }

    private fun startObserving() {
        scope.launch(exceptionHandler) {
            Wearables.registrationState.collect { state ->
                registrationState = state
                emitTelemetrySnapshot()
            }
        }
        scope.launch(exceptionHandler) {
            Wearables.devices.collect { identifiers ->
                val removed = metadataJobs.keys - identifiers
                for (id in removed) {
                    metadataJobs.remove(id)?.cancel()
                }
                for (id in identifiers) {
                    if (!metadataJobs.containsKey(id)) {
                        metadataJobs[id] = scope.launch(exceptionHandler) {
                            Wearables.devicesMetadata[id]?.collect { device ->
                                latestDevice = device
                                emitTelemetrySnapshot()
                            }
                        }
                    }
                }
                if (identifiers.isEmpty()) {
                    latestDevice = null
                    emitTelemetrySnapshot()
                }
            }
        }
    }

    fun startRegistration(activity: Activity): Boolean {
        ensureInitialized()
        if (!initialized) return false
        return try {
            if (registrationState != RegistrationState.REGISTERED) {
                Wearables.startRegistration(activity)
            }
            true
        } catch (e: Throwable) {
            Log.w(TAG, "startRegistration failed: ${e.message}")
            false
        }
    }

    fun enableMockDisplayDevice(): Map<String, Any?> {
        ensureInitialized()
        try {
            if (mockGlasses == null) {
                val kit = MockDeviceKit.getInstance(appContext)
                kit.enable()
                kit.pairGlasses(GlassesModel.META_RAYBAN_DISPLAY).fold(
                    onSuccess = { glasses ->
                        glasses.powerOn()
                        glasses.don()
                        mockGlasses = glasses
                        mockDeviceId = glasses.deviceIdentifier
                    },
                    onFailure = { err, _ ->
                        Log.w(TAG, "MockDeviceKit pairGlasses failed: $err")
                    },
                )
            }
        } catch (e: Throwable) {
            Log.w(TAG, "enableMockDisplayDevice failed: ${e.message}")
        }
        emitTelemetrySnapshot()
        return buildTelemetryMap()
    }

    fun disableMockDisplayDevice(): Map<String, Any?> {
        try {
            stopDisplaySession()
            val kit = MockDeviceKit.getInstance(appContext)
            kit.stopTestServer()
            chromePreviewUrl = null
            mockGlasses?.doff()
            mockGlasses?.powerOff()
            mockGlasses = null
            mockDeviceId = null
            kit.disable()
        } catch (e: Throwable) {
            Log.w(TAG, "disableMockDisplayDevice failed: ${e.message}")
        }
        emitTelemetrySnapshot()
        return buildTelemetryMap()
    }

    fun pushDisplayWord(word: String, meaningHint: String, languagePair: String): Boolean {
        ensureInitialized()
        if (!initialized) return false
        pendingWord = Triple(word, meaningHint, languagePair)

        val activeDisplay = display
        if (activeDisplay != null && displayReady) {
            renderWordOnDisplay(activeDisplay, word, meaningHint, languagePair)
            return true
        }

        return startDisplaySessionAndSend()
    }

    fun clearDisplayHud(): Boolean {
        pendingWord = null
        val activeDisplay = display ?: return false
        if (!displayReady) return false
        scope.launch(exceptionHandler) {
            activeDisplay.sendContent {
                flexBox(direction = Direction.COLUMN, alignment = Alignment.CENTER) {
                    text("TipTongue", style = TextStyle.META, color = TextColor.SECONDARY)
                    text("Lens clear", style = TextStyle.BODY, color = TextColor.SECONDARY)
                }
            }
        }
        return true
    }

    private fun startDisplaySessionAndSend(): Boolean {
        if (session != null) return true
        val selector = mockDeviceId?.let { SpecificDeviceSelector(it) }
            ?: AutoDeviceSelector(filter = { it.isDisplayCapable() })

        val result = Wearables.createSession(selector)
        return result.fold(
            onSuccess = { newSession ->
                session = newSession
                scope.launch(exceptionHandler) {
                    newSession.state.collect { state ->
                        when (state) {
                            DeviceSessionState.STARTED -> attachDisplay(newSession)
                            DeviceSessionState.STOPPED -> {
                                display = null
                                displayReady = false
                                session = null
                                emitTelemetrySnapshot()
                            }
                            else -> Unit
                        }
                    }
                }
                newSession.start()
                true
            },
            onFailure = { error, _ ->
                Log.w(TAG, "createSession failed: ${error.description}")
                false
            },
        )
    }

    private fun attachDisplay(activeSession: DeviceSession) {
        activeSession.addDisplay().fold(
            onSuccess = { newDisplay ->
                display = newDisplay
                scope.launch(exceptionHandler) {
                    newDisplay.state.collect { state ->
                        displayReady = state == DisplayState.STARTED
                        emitTelemetrySnapshot()
                        if (displayReady) {
                            pendingWord?.let { (word, meaning, languagePair) ->
                                renderWordOnDisplay(newDisplay, word, meaning, languagePair)
                            }
                        }
                    }
                }
            },
            onFailure = { error, _ ->
                Log.w(TAG, "addDisplay failed: ${error.description}")
            },
        )
    }

    private fun renderWordOnDisplay(
        targetDisplay: Display,
        word: String,
        meaningHint: String,
        languagePair: String,
    ) {
        scope.launch(exceptionHandler) {
            targetDisplay.sendContent {
                flexBox(direction = Direction.COLUMN, gap = 10) {
                    flexBox(padding = 24, background = FlexBoxBackground.CARD) {
                        val header = if (languagePair.isNotBlank()) "TipTongue · $languagePair" else "TipTongue"
                        text(header, style = TextStyle.META, color = TextColor.SECONDARY)
                        // Surface only the exact ready-to-speak inflected word (no grammar tags)
                        text(word, style = TextStyle.HEADING)
                    }
                    flexBox(
                        direction = Direction.ROW,
                        gap = 8,
                        alignment = Alignment.CENTER,
                        crossAlignment = Alignment.CENTER,
                    ) {
                        buttonGroup {
                            button(
                                "Dismiss",
                                style = ButtonStyle.SECONDARY,
                                onClick = { clearDisplayHud() },
                            )
                        }
                    }
                }
            }
        }
    }

    private fun stopDisplaySession() {
        try {
            session?.removeDisplay()
            session?.stop()
        } catch (_: Throwable) {
        } finally {
            display = null
            displayReady = false
            session = null
        }
    }

    fun buildTelemetryMap(): Map<String, Any?> {
        val dev = latestDevice
        val donText = dev?.donState?.name?.lowercase() ?: "donned"
        val hingeText = dev?.hingeState?.name?.lowercase() ?: "open"
        val chargeText = dev?.chargingState?.name?.lowercase() ?: "not_charging"
        val thermalText = dev?.thermalLevel?.name?.lowercase() ?: "nominal"

        val isDonned = !donText.contains("doff")
        val isHingeOpen = !hingeText.contains("clos")
        val isCharging = chargeText.contains("charg") && !chargeText.contains("not")

        return mapOf(
            "datAvailable" to initialized,
            "datSdkVersion" to "1.0.1",
            "datRegistrationState" to registrationState.name.lowercase(),
            "isOfficialMockActive" to (mockGlasses != null),
            "isDisplayAttached" to displayReady,
            "isDonned" to isDonned,
            "isHingeOpen" to isHingeOpen,
            "batteryLevel" to dev?.batteryLevel,
            "isCharging" to isCharging,
            "thermalLevel" to thermalText,
            "chromePreviewUrl" to chromePreviewUrl,
        )
    }

    private fun emitTelemetrySnapshot() {
        val payload = buildTelemetryMap()
        mainHandler.post {
            try {
                eventSink?.success(payload)
            } catch (_: Throwable) {
            }
        }
    }

    fun dispose() {
        stopDisplaySession()
        scope.cancel()
    }
}
