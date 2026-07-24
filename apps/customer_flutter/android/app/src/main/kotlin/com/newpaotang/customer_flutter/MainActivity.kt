package com.newpaotang.customer_flutter

import android.annotation.TargetApi
import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.WindowManager
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

class MainActivity : FlutterFragmentActivity() {
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
    private var activeScreenSecurityRoute = ""
    private var screenSecurityMethodChannel: MethodChannel? = null
    private var screenCaptureCallback: Any? = null

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
        updateScreenCaptureDetection()
    }

    override fun onStop() {
        super.onStop()
        unregisterScreenCaptureCallbackIfNeeded()
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
                    screenSecurityActive = true
                    activeScreenSecurityRoute =
                        stringArg(args, screenSecurityRouteKeys, activeScreenSecurityRoute)
                    flagSecureEnabled = boolArg(args, "flag_secure", true)
                    protectRecentAppPreviewEnabled =
                        boolArg(args, "protect_recent_app_preview", true)
                    applyScreenSecurityPolicy()
                    updateScreenCaptureDetection()
                    result.success(null)
                }
                "disable" -> {
                    screenSecurityActive = false
                    activeScreenSecurityRoute = ""
                    applyScreenSecurityPolicy()
                    updateScreenCaptureDetection()
                    result.success(null)
                }
                "reportSecurityEvent" -> {
                    val args = call.arguments as? Map<*, *>
                    screenSecurityActive = true
                    activeScreenSecurityRoute =
                        stringArg(args, screenSecurityRouteKeys, activeScreenSecurityRoute)
                    flagSecureEnabled = boolArg(args, "flag_secure", flagSecureEnabled)
                    protectRecentAppPreviewEnabled =
                        boolArg(args, "protect_recent_app_preview", protectRecentAppPreviewEnabled)
                    applyScreenSecurityPolicy()
                    updateScreenCaptureDetection()
                    sendSecurityEvent(
                        screenSecurityMethodChannel,
                        args,
                        activeScreenSecurityRoute
                    )
                    result.success(null)
                }
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

    private fun updateScreenCaptureDetection() {
        if (Build.VERSION.SDK_INT < 34) {
            return
        }
        if (screenSecurityActive && activeScreenSecurityRoute.isNotBlank()) {
            registerScreenCaptureCallbackIfNeeded()
        } else {
            unregisterScreenCaptureCallbackIfNeeded()
        }
    }

    @TargetApi(34)
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

    @TargetApi(34)
    private fun unregisterScreenCaptureCallbackIfNeeded() {
        if (Build.VERSION.SDK_INT < 34) {
            screenCaptureCallback = null
            return
        }
        val callback = screenCaptureCallback as? Activity.ScreenCaptureCallback ?: return
        unregisterScreenCaptureCallback(callback)
        screenCaptureCallback = null
    }

    private fun handleScreenCaptured() {
        val route = activeScreenSecurityRoute.trim()
        val channel = screenSecurityMethodChannel ?: return
        if (!screenSecurityActive || route.isEmpty()) {
            return
        }
        sendSecurityEvent(
            channel,
            mapOf(
                "event" to "screenshot_detected",
                "eventName" to "screenshot_detected",
                "nativeEvent" to "android_screen_capture_callback",
                "route" to route,
                "currentRoute" to route,
                "reason" to "screenshot",
                "reasonText" to "screenshot",
                "screenCaptureActive" to true,
                "source" to "android_screen_capture_callback"
            ),
            route
        )
    }

    private fun applyScreenSecurityPolicy() {
        val recentsApiAvailable = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        val secureWindowRequired =
            screenSecurityActive &&
                (flagSecureEnabled || (protectRecentAppPreviewEnabled && !recentsApiAvailable))

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
                !(screenSecurityActive && protectRecentAppPreviewEnabled)
            )
        }
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
