package com.newpaotang.customer_flutter

import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.WindowManager
import android.widget.Toast
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.UnrecoverableKeyException
import java.security.spec.ECGenParameterSpec
import java.util.UUID
import java.util.function.Consumer
import kotlin.system.exitProcess

class MainActivity : FlutterFragmentActivity() {
    private val appWideScreenSecurity = true
    private val appWideScreenSecurityRoute = "app"
    private val screenSecurityExitDelayMillis = 900L
    private val screenSecurityChannel = "customer_flutter/screen_security"
    private val biometricKeysChannel = "customer_flutter/biometric_keys"
    private val keyAlias: String
        get() = "${packageName}.biometric_p256"
    private val prefsName: String
        get() = "${packageName}.secure_device"
    private val deviceIdKey = "biometric_device_id"
    private var screenSecurityActive = true
    private var flagSecureEnabled = true
    private var protectRecentAppPreviewEnabled = true
    private var routeSecurityExemptionActive = false
    private var activeScreenSecurityRoute = appWideScreenSecurityRoute
    private var screenSecurityMethodChannel: MethodChannel? = null
    private var screenCaptureCallback: Any? = null
    private var screenRecordingCallback: Consumer<Int>? = null
    private var lastScreenRecordingState: Int? = null
    private var activityStarted = false
    private var captureBlockedMessage = ""
    private var captureTerminationScheduled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
        super.onCreate(savedInstanceState)
    }

    override fun onStart() {
        super.onStart()
        activityStarted = true
        applyScreenSecurityPolicy()
        updateScreenSecurityDetection()
    }

    override fun onStop() {
        activityStarted = false
        unregisterScreenCaptureCallbackIfNeeded()
        unregisterScreenRecordingCallbackIfNeeded()
        super.onStop()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val screenSecurityMethodChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenSecurityChannel)
        this.screenSecurityMethodChannel = screenSecurityMethodChannel
        screenSecurityMethodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    val args = call.arguments as? Map<*, *>
                    routeSecurityExemptionActive = false
                    screenSecurityActive = true
                    activeScreenSecurityRoute =
                        stringArg(args, screenSecurityRouteKeys, currentScreenSecurityRoute())
                    captureBlockedMessage =
                        stringArg(args, screenSecurityTitleKeys, captureBlockedMessage)
                    flagSecureEnabled =
                        appWideScreenSecurity || boolArg(args, "flag_secure", true)
                    protectRecentAppPreviewEnabled =
                        appWideScreenSecurity ||
                            boolArg(args, "protect_recent_app_preview", true)
                    applyScreenSecurityPolicy()
                    updateScreenSecurityDetection()
                    result.success(null)
                }
                "disable" -> {
                    val args = call.arguments as? Map<*, *>
                    val allowRouteExemption =
                        boolArg(args, "allow_route_exemption", false)
                    if (appWideScreenSecurity && !allowRouteExemption) {
                        enforceAppWideScreenSecurity()
                    } else {
                        routeSecurityExemptionActive = allowRouteExemption
                        screenSecurityActive = false
                        activeScreenSecurityRoute =
                            stringArg(args, screenSecurityRouteKeys, "")
                    }
                    applyScreenSecurityPolicy()
                    updateScreenSecurityDetection()
                    result.success(null)
                }
                "reportSecurityEvent" -> {
                    val args = call.arguments as? Map<*, *>
                    routeSecurityExemptionActive = false
                    screenSecurityActive = true
                    activeScreenSecurityRoute =
                        stringArg(args, screenSecurityRouteKeys, currentScreenSecurityRoute())
                    captureBlockedMessage =
                        stringArg(args, screenSecurityTitleKeys, captureBlockedMessage)
                    flagSecureEnabled =
                        appWideScreenSecurity ||
                            boolArg(args, "flag_secure", flagSecureEnabled)
                    protectRecentAppPreviewEnabled =
                        appWideScreenSecurity ||
                            boolArg(
                                args,
                                "protect_recent_app_preview",
                                protectRecentAppPreviewEnabled
                            )
                    applyScreenSecurityPolicy()
                    updateScreenSecurityDetection()
                    sendSecurityEvent(
                        screenSecurityMethodChannel,
                        args,
                        activeScreenSecurityRoute
                    )
                    result.success(null)
                }
                "getSecurityState" -> result.success(screenSecurityState())
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, biometricKeysChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "existingDeviceId" -> result.success(existingDeviceId())
                        "hasExistingKeyPair" -> result.success(hasExistingKeyPair())
                        "restoreDeviceId" -> {
                            val args = call.arguments as? Map<*, *>
                            val deviceId = (
                                args?.get("deviceId")
                                    ?: args?.get("device_id")
                                    ?: args?.get("credentialId")
                                    ?: args?.get("credential_id")
                                )?.toString()?.trim().orEmpty()
                            if (deviceId.isBlank() || !hasExistingKeyPair()) {
                                result.success(false)
                            } else {
                                getSharedPreferences(prefsName, MODE_PRIVATE)
                                    .edit()
                                    .putString(deviceIdKey, deviceId)
                                    .apply()
                                result.success(true)
                            }
                        }
                        "deviceId" -> result.success(currentDeviceId())
                        "deleteKeyPair" -> {
                            deleteKeyPair()
                            result.success(true)
                        }
                        "createKeyPair" -> {
                            val publicKey = ensureKeyPair()
                            val deviceId = currentDeviceId()
                            result.success(
                                mapOf(
                                    "deviceId" to deviceId,
                                    "credentialId" to deviceId,
                                    "rawId" to deviceId,
                                    "publicKeyPem" to publicKey,
                                    "publicKey" to publicKey,
                                    "algorithm" to "ES256",
                                    "signingAlgorithm" to "ES256",
                                    "keyAlgorithm" to "ES256"
                                )
                            )
                        }
                        "signChallenge" -> {
                            val args = call.arguments as? Map<*, *>
                            val challenge = args?.get("challenge")?.toString().orEmpty()
                            if (challenge.isBlank()) {
                                result.error("invalid_challenge", "Challenge is required.", null)
                            } else {
                                result.success(signChallengePayload(challenge))
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    if (isBiometricKeyInvalidated(error)) {
                        runCatching { deleteKeyPair() }
                        result.error(
                            "biometric_key_invalidated",
                            "Biometric enrollment changed. Register this device again.",
                            null
                        )
                    } else {
                        result.error(
                            "biometric_key_error",
                            error.message ?: "Biometric key operation failed.",
                            null
                        )
                    }
                }
        }
    }

    private fun updateScreenSecurityDetection() {
        updateScreenCaptureDetection()
        updateScreenRecordingDetection()
    }

    private fun updateScreenCaptureDetection() {
        if (Build.VERSION.SDK_INT < 34) {
            return
        }
        if (
            activityStarted &&
            screenSecurityActive &&
            currentScreenSecurityRoute().isNotBlank()
        ) {
            registerScreenCaptureCallbackIfNeeded()
        } else {
            unregisterScreenCaptureCallbackIfNeeded()
        }
    }

    private fun updateScreenRecordingDetection() {
        if (Build.VERSION.SDK_INT < 35) {
            return
        }
        if (
            activityStarted &&
            screenSecurityActive &&
            currentScreenSecurityRoute().isNotBlank()
        ) {
            registerScreenRecordingCallbackIfNeeded()
        } else {
            unregisterScreenRecordingCallbackIfNeeded()
        }
    }

    @RequiresApi(34)
    private fun registerScreenCaptureCallbackIfNeeded() {
        if (screenCaptureCallback != null) {
            return
        }
        val callback = Activity.ScreenCaptureCallback {
            handleScreenCaptured()
        }
        screenCaptureCallback = callback
        registerScreenCaptureCallback(mainExecutor, callback)
    }

    private fun unregisterScreenCaptureCallbackIfNeeded() {
        if (Build.VERSION.SDK_INT < 34) {
            screenCaptureCallback = null
            return
        }
        unregisterScreenCaptureCallbackApi34()
    }

    @RequiresApi(34)
    private fun unregisterScreenCaptureCallbackApi34() {
        val callback = screenCaptureCallback as? Activity.ScreenCaptureCallback ?: return
        unregisterScreenCaptureCallback(callback)
        screenCaptureCallback = null
    }

    @RequiresApi(35)
    private fun registerScreenRecordingCallbackIfNeeded() {
        if (screenRecordingCallback != null) {
            return
        }
        val callback = Consumer<Int> { state ->
            handleScreenRecordingState(state)
        }
        screenRecordingCallback = callback
        val initialState = windowManager.addScreenRecordingCallback(mainExecutor, callback)
        handleScreenRecordingState(initialState, emitEnded = false)
    }

    private fun unregisterScreenRecordingCallbackIfNeeded() {
        if (Build.VERSION.SDK_INT < 35) {
            screenRecordingCallback = null
            lastScreenRecordingState = null
            return
        }
        val callback = screenRecordingCallback ?: return
        windowManager.removeScreenRecordingCallback(callback)
        screenRecordingCallback = null
        lastScreenRecordingState = null
    }

    @RequiresApi(35)
    private fun handleScreenRecordingState(state: Int, emitEnded: Boolean = true) {
        val previousState = lastScreenRecordingState
        if (previousState == state) {
            return
        }
        lastScreenRecordingState = state

        val recordingVisible = state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE
        if (
            !recordingVisible &&
            (!emitEnded || previousState != WindowManager.SCREEN_RECORDING_STATE_VISIBLE)
        ) {
            return
        }

        val route = currentScreenSecurityRoute()
        if (!screenSecurityActive || route.isEmpty()) {
            return
        }
        if (recordingVisible) {
            requestScreenSecurityExit(
                reason = "screen_recording",
                source = "android_screen_recording_callback"
            )
        } else {
            sendNativeSecurityEvent(
                event = "screen_capture_ended",
                route = route,
                reason = "screen_recording",
                source = "android_screen_recording_callback",
                captureActive = false
            )
        }
    }

    private fun handleScreenCaptured() {
        val route = currentScreenSecurityRoute()
        if (!screenSecurityActive || route.isEmpty()) {
            return
        }
        requestScreenSecurityExit(
            reason = "screenshot",
            source = "android_screen_capture_callback"
        )
    }

    private fun requestScreenSecurityExit(
        reason: String,
        source: String
    ) {
        if (captureTerminationScheduled) {
            return
        }
        captureTerminationScheduled = true
        val route = currentScreenSecurityRoute()
        sendNativeSecurityEvent(
            event = "screen_security_exit_requested",
            route = route,
            reason = reason,
            source = source,
            captureActive = true
        )
        runOnUiThread {
            Toast.makeText(
                applicationContext,
                captureBlockedMessage.ifBlank {
                    getString(R.string.screen_capture_not_allowed)
                },
                Toast.LENGTH_LONG
            ).show()
            Handler(Looper.getMainLooper()).postDelayed(
                {
                    finishAndRemoveTask()
                    exitProcess(0)
                },
                screenSecurityExitDelayMillis
            )
        }
    }

    private fun sendNativeSecurityEvent(
        event: String,
        route: String,
        reason: String,
        source: String,
        captureActive: Boolean
    ) {
        screenSecurityMethodChannel?.invokeMethod(
            "securityEvent",
            mapOf(
                "event" to event,
                "eventName" to event,
                "nativeEvent" to source,
                "route" to route,
                "currentRoute" to route,
                "reason" to reason,
                "reasonText" to reason,
                "screenCaptureActive" to captureActive,
                "mediaProjectionActive" to captureActive,
                "source" to source
            )
        )
    }

    private fun screenSecurityState(): Map<String, Any> {
        val windowFlagSecure =
            (window.attributes.flags and WindowManager.LayoutParams.FLAG_SECURE) != 0
        val recentsProtected =
            screenSecurityActive &&
                protectRecentAppPreviewEnabled &&
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU || windowFlagSecure)
        return mapOf(
            "sdkInt" to Build.VERSION.SDK_INT,
            "activityStarted" to activityStarted,
            "appWideProtection" to appWideScreenSecurity,
            "routeSecurityExemptionActive" to routeSecurityExemptionActive,
            "screenSecurityActive" to screenSecurityActive,
            "activeRoute" to currentScreenSecurityRoute(),
            "flagSecureConfigured" to flagSecureEnabled,
            "protectRecentAppPreviewConfigured" to protectRecentAppPreviewEnabled,
            "windowFlagSecure" to windowFlagSecure,
            "recentAppPreviewProtected" to recentsProtected,
            "screenCaptureCallbackRegistered" to (screenCaptureCallback != null),
            "screenRecordingCallbackRegistered" to (screenRecordingCallback != null),
            "screenRecordingDetectionSupported" to (Build.VERSION.SDK_INT >= 35),
            "captureTerminationScheduled" to captureTerminationScheduled
        )
    }

    private fun applyScreenSecurityPolicy() {
        if (appWideScreenSecurity && !routeSecurityExemptionActive) {
            enforceAppWideScreenSecurity()
        }
        val recentsApiAvailable = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        val secureWindowRequired =
            (appWideScreenSecurity && !routeSecurityExemptionActive) ||
                (screenSecurityActive &&
                    (
                        flagSecureEnabled ||
                            (protectRecentAppPreviewEnabled && !recentsApiAvailable)
                        ))

        if (secureWindowRequired) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            )
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }

        if (recentsApiAvailable) {
            setRecentsScreenshotEnabled(
                !((appWideScreenSecurity && !routeSecurityExemptionActive) ||
                    (screenSecurityActive && protectRecentAppPreviewEnabled))
            )
        }
    }

    private fun enforceAppWideScreenSecurity() {
        routeSecurityExemptionActive = false
        screenSecurityActive = true
        flagSecureEnabled = true
        protectRecentAppPreviewEnabled = true
        if (activeScreenSecurityRoute.isBlank()) {
            activeScreenSecurityRoute = appWideScreenSecurityRoute
        }
    }

    private fun currentScreenSecurityRoute(): String {
        return activeScreenSecurityRoute.trim().ifEmpty { appWideScreenSecurityRoute }
    }

    private fun boolArg(args: Map<*, *>?, key: String, fallback: Boolean): Boolean {
        val value = args?.get(key) ?: return fallback
        return when (value) {
            is Boolean -> value
            is Number -> value.toInt() != 0
            is String -> {
                when (value.trim().lowercase()) {
                    "1",
                    "true",
                    "yes",
                    "y",
                    "on",
                    "enable",
                    "enabled",
                    "active",
                    "available",
                    "allowed",
                    "supported",
                    "ready",
                    "protect",
                    "protected",
                    "secure",
                    "secured" -> true
                    "0",
                    "false",
                    "no",
                    "n",
                    "off",
                    "disable",
                    "disabled",
                    "inactive",
                    "unavailable",
                    "blocked",
                    "hidden",
                    "unsupported",
                    "not_supported",
                    "not_allowed",
                    "unprotected" -> false
                    else -> fallback
                }
            }
            else -> fallback
        }
    }

    private fun sendSecurityEvent(
        channel: MethodChannel,
        args: Map<*, *>?,
        fallbackRoute: String
    ) {
        val event = stringArg(args, screenSecurityEventKeys, "screen_capture")
        val route = stringArg(args, screenSecurityRouteKeys, fallbackRoute)
        val reason = stringArg(args, screenSecurityReasonKeys, "")
        val payload = mutableMapOf<String, Any>(
            "event" to event,
            "eventName" to event,
            "route" to route,
            "currentRoute" to route,
            "source" to "android_report_security_event"
        )
        if (reason.isNotBlank()) {
            payload["reason"] = reason
            payload["reasonText"] = reason
        }
        val captureActive = firstArg(args, screenSecurityCaptureStateKeys)
        if (captureActive != null) {
            payload["screenCaptureActive"] = captureActive
        }
        channel.invokeMethod("securityEvent", payload)
    }

    private fun stringArg(args: Map<*, *>?, key: String, fallback: String): String {
        return stringArg(args, listOf(key), fallback)
    }

    private fun stringArg(args: Map<*, *>?, keys: List<String>, fallback: String): String {
        val value = firstArg(args, keys)?.toString()?.trim().orEmpty()
        return value.ifEmpty { fallback }
    }

    private fun firstArg(args: Map<*, *>?, keys: List<String>): Any? {
        if (args == null) return null
        for (key in keys) {
            val value = args[key] ?: continue
            if (value is String && value.trim().isEmpty()) continue
            return value
        }
        return null
    }

    private val screenSecurityEventKeys = listOf(
        "event",
        "eventName",
        "event_name",
        "eventType",
        "event_type",
        "eventAction",
        "event_action",
        "nativeEvent",
        "native_event",
        "action",
        "type",
        "name"
    )

    private val screenSecurityRouteKeys = listOf(
        "route",
        "routeName",
        "route_name",
        "routePath",
        "route_path",
        "path",
        "fullPath",
        "full_path",
        "currentRoute",
        "current_route",
        "currentPath",
        "current_path",
        "screen",
        "screenName",
        "screen_name",
        "currentScreen",
        "current_screen",
        "url",
        "currentUrl",
        "current_url",
        "location",
        "href",
        "uri"
    )

    private val screenSecurityTitleKeys = listOf(
        "overlay_title",
        "overlayTitle",
        "privacy_overlay_title",
        "privacyOverlayTitle",
        "screen_capture_title",
        "screenCaptureTitle",
        "security_capture_title",
        "securityCaptureTitle"
    )

    private val screenSecurityReasonKeys = listOf(
        "reason",
        "reasonName",
        "reason_name",
        "reasonCode",
        "reason_code",
        "reasonText",
        "reason_text",
        "cause",
        "message",
        "description",
        "source",
        "sourceName",
        "source_name",
        "trigger",
        "triggerName",
        "trigger_name",
        "detail",
        "details"
    )

    private val screenSecurityCaptureStateKeys = listOf(
        "screenCaptureActive",
        "screen_capture_active",
        "screenCaptured",
        "screen_captured",
        "isCaptured",
        "is_captured",
        "captureActive",
        "capture_active",
        "mediaProjectionActive",
        "media_projection_active"
    )

    private fun currentDeviceId(): String {
        val existing = existingDeviceId()
        if (!existing.isNullOrBlank()) {
            return existing
        }

        val created = "android-${UUID.randomUUID()}"
        getSharedPreferences(prefsName, MODE_PRIVATE)
            .edit()
            .putString(deviceIdKey, created)
            .apply()
        return created
    }

    private fun existingDeviceId(): String? {
        val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
        val stored = prefs.getString(deviceIdKey, null)?.trim()
        if (stored.isNullOrEmpty()) {
            return null
        }
        if (!hasExistingKeyPair()) {
            prefs.edit().remove(deviceIdKey).apply()
            return null
        }
        return stored
    }

    private fun hasExistingKeyPair(): Boolean {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        return keyStore.containsAlias(keyAlias)
    }

    private fun deleteKeyPair() {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (keyStore.containsAlias(keyAlias)) {
            keyStore.deleteEntry(keyAlias)
        }
        getSharedPreferences(prefsName, MODE_PRIVATE)
            .edit()
            .remove(deviceIdKey)
            .apply()
    }

    private fun isBiometricKeyInvalidated(error: Throwable): Boolean {
        var current: Throwable? = error
        while (current != null) {
            if (current is KeyPermanentlyInvalidatedException ||
                current is UnrecoverableKeyException
            ) {
                return true
            }
            current = current.cause
        }
        return false
    }

    private fun ensureKeyPair(): String {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (!keyStore.containsAlias(keyAlias)) {
            val generator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_EC,
                "AndroidKeyStore"
            )
            val builder = KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
            )
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setUserAuthenticationRequired(true)
                .setInvalidatedByBiometricEnrollment(true)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                builder.setUserAuthenticationParameters(
                    30,
                    KeyProperties.AUTH_BIOMETRIC_STRONG
                )
            } else {
                @Suppress("DEPRECATION")
                builder.setUserAuthenticationValidityDurationSeconds(30)
            }

            generator.initialize(builder.build())
            generator.generateKeyPair()
        }

        val publicKey = keyStore.getCertificate(keyAlias).publicKey.encoded
        return pem("PUBLIC KEY", publicKey)
    }

    private fun signChallenge(challenge: String): String {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val privateKey = keyStore.getKey(keyAlias, null) as? PrivateKey
            ?: throw IllegalStateException("Biometric key is not registered.")
        val signature = Signature.getInstance("SHA256withECDSA")
        signature.initSign(privateKey)
        signature.update(challenge.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(signature.sign(), Base64.NO_WRAP)
    }

    private fun signChallengePayload(challenge: String): Map<String, Any> {
        val signature = signChallenge(challenge)
        val deviceId = existingDeviceId().orEmpty()
        val payload = mutableMapOf<String, Any>(
            "signature" to signature,
            "signatureBase64" to signature,
            "signatureDer" to signature,
            "signedPayload" to challenge,
            "algorithm" to "ES256",
            "signingAlgorithm" to "ES256",
            "keyAlgorithm" to "ES256"
        )
        if (deviceId.isNotBlank()) {
            payload["deviceId"] = deviceId
            payload["credentialId"] = deviceId
            payload["rawId"] = deviceId
        }
        return payload
    }

    private fun pem(label: String, der: ByteArray): String {
        val body = Base64.encodeToString(der, Base64.NO_WRAP)
            .chunked(64)
            .joinToString("\n")
        return "-----BEGIN $label-----\n$body\n-----END $label-----"
    }
}
