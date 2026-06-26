package com.newpaotang.customer_flutter

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.UUID
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    private val screenSecurityChannel = "customer_flutter/screen_security"
    private val biometricKeysChannel = "customer_flutter/biometric_keys"
    private val keyAlias: String
        get() = "${packageName}.biometric_p256"
    private val prefsName: String
        get() = "${packageName}.secure_device"
    private val deviceIdKey = "biometric_device_id"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenSecurityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE
                        )
                        result.success(null)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "reportSecurityEvent" -> {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE
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
                        "deviceId" -> result.success(currentDeviceId())
                        "createKeyPair" -> {
                            val publicKey = ensureKeyPair()
                            result.success(
                                mapOf(
                                    "deviceId" to currentDeviceId(),
                                    "publicKeyPem" to publicKey,
                                    "algorithm" to "ES256"
                                )
                            )
                        }
                        "signChallenge" -> {
                            val args = call.arguments as? Map<*, *>
                            val challenge = args?.get("challenge")?.toString().orEmpty()
                            if (challenge.isBlank()) {
                                result.error("invalid_challenge", "Challenge is required.", null)
                            } else {
                                result.success(signChallenge(challenge))
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error(
                        "biometric_key_error",
                        error.message ?: "Biometric key operation failed.",
                        null
                    )
                }
            }
    }

    private fun currentDeviceId(): String {
        val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
        val existing = prefs.getString(deviceIdKey, null)
        if (!existing.isNullOrBlank()) {
            return existing
        }

        val created = "android-${UUID.randomUUID()}"
        prefs.edit().putString(deviceIdKey, created).apply()
        return created
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
                    KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL
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

    private fun pem(label: String, der: ByteArray): String {
        val body = Base64.encodeToString(der, Base64.NO_WRAP)
            .chunked(64)
            .joinToString("\n")
        return "-----BEGIN $label-----\n$body\n-----END $label-----"
    }
}
