package com.example.raahi

import android.content.pm.PackageManager
import android.net.Uri
import android.telephony.SmsManager
import android.telecom.TelecomManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val SMS_CHANNEL = "com.example.raahi/emergency_sms"
        const val CALL_CHANNEL = "com.example.raahi/emergency_call"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SMS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "sendSms") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            if (checkSelfPermission(android.Manifest.permission.SEND_SMS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                result.error("SMS_PERMISSION_DENIED", "SMS permission is not granted", null)
                return@setMethodCallHandler
            }

            val phone = call.argument<String>("phone")
            val message = call.argument<String>("message")
            if (phone.isNullOrBlank() || message.isNullOrBlank()) {
                result.error("INVALID_SMS", "Phone number and message are required", null)
                return@setMethodCallHandler
            }

            try {
                SmsManager.getDefault().sendTextMessage(
                    phone,
                    null,
                    message,
                    null,
                    null,
                )
                result.success(true)
            } catch (error: Exception) {
                result.error("SMS_SEND_FAILED", error.message, null)
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALL_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "callEmergencyNumber") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            if (checkSelfPermission(android.Manifest.permission.CALL_PHONE) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                result.error("CALL_PERMISSION_DENIED", "Call permission is not granted", null)
                return@setMethodCallHandler
            }

            val phone = call.argument<String>("phone")
            if (phone.isNullOrBlank()) {
                result.error("INVALID_PHONE", "Phone number is required", null)
                return@setMethodCallHandler
            }

            try {
                val telecomManager = getSystemService(TELECOM_SERVICE) as TelecomManager
                telecomManager.placeCall(
                    Uri.parse("tel:$phone"),
                    Bundle(),
                )
                result.success(true)
            } catch (error: Exception) {
                result.error("CALL_FAILED", error.message, null)
            }
        }
    }
}
