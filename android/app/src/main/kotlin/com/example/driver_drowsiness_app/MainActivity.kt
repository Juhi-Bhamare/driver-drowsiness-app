package com.example.driver_drowsiness_app

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SmsManager
import android.net.Uri
import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "driver_drowsiness/sos"

    private val smsPermissionRequestCode = 1001
    private val callPermissionRequestCode = 1002

    private var pendingPhoneNumbers: List<String> = emptyList()
    private var pendingMessage: String = ""
    private var pendingResult: MethodChannel.Result? = null

    private var pendingCallNumber: String? = null
    private var pendingCallResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "sendEmergencySms" -> {

                    val phoneNumbers =
                        call.argument<List<String>>("phoneNumbers")

                    val message =
                        call.argument<String>("message")

                    if (
                        phoneNumbers == null ||
                        phoneNumbers.isEmpty() ||
                        message.isNullOrEmpty()
                    ) {
                        result.error(
                            "INVALID_DATA",
                            "Phone numbers or message is missing.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    sendEmergencySms(
                        phoneNumbers,
                        message,
                        result
                    )
                }

                "makeEmergencyCall" -> {

                    val phoneNumber =
                        call.argument<String>("phoneNumber")

                    if (
                        phoneNumber == null ||
                        phoneNumber.trim().isEmpty()
                    ) {
                        result.error(
                            "INVALID_PHONE",
                            "Emergency phone number is missing.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    makeEmergencyCall(
                        phoneNumber.trim(),
                        result
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ==========================================================
    // EMERGENCY SMS
    // ==========================================================

    private fun sendEmergencySms(
        phoneNumbers: List<String>,
        message: String,
        result: MethodChannel.Result
    ) {

        val permissionGranted =
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.SEND_SMS
            ) == PackageManager.PERMISSION_GRANTED

        if (!permissionGranted) {

            pendingPhoneNumbers = phoneNumbers
            pendingMessage = message
            pendingResult = result

            requestPermissions(
                arrayOf(
                    Manifest.permission.SEND_SMS
                ),
                smsPermissionRequestCode
            )

            return
        }

        sendSmsNow(
            phoneNumbers,
            message,
            result
        )
    }

    private fun sendSmsNow(
        phoneNumbers: List<String>,
        message: String,
        result: MethodChannel.Result
    ) {

        try {

            val smsManager =
                SmsManager.getDefault()

            for (phoneNumber in phoneNumbers) {

                smsManager.sendTextMessage(
                    phoneNumber,
                    null,
                    message,
                    null,
                    null
                )
            }

            result.success(true)

        } catch (e: Exception) {

            result.error(
                "SMS_FAILED",
                e.message,
                null
            )
        }
    }

    // ==========================================================
    // EMERGENCY PHONE CALL
    // ==========================================================

    private fun makeEmergencyCall(
        phoneNumber: String,
        result: MethodChannel.Result
    ) {

        val permissionGranted =
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.CALL_PHONE
            ) == PackageManager.PERMISSION_GRANTED

        if (!permissionGranted) {

            pendingCallNumber = phoneNumber
            pendingCallResult = result

            requestPermissions(
                arrayOf(
                    Manifest.permission.CALL_PHONE
                ),
                callPermissionRequestCode
            )

            return
        }

        placeCallNow(
            phoneNumber,
            result
        )
    }

    private fun placeCallNow(
        phoneNumber: String,
        result: MethodChannel.Result
    ) {

        try {

            val intent = Intent(
                Intent.ACTION_CALL,
                Uri.parse("tel:$phoneNumber")
            )

            startActivity(intent)

            result.success(true)

        } catch (e: Exception) {

            result.error(
                "CALL_FAILED",
                e.message,
                null
            )
        }
    }

    // ==========================================================
    // PERMISSION RESULTS
    // ==========================================================

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {

        super.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults
        )

        // SMS permission
        if (
            requestCode ==
            smsPermissionRequestCode
        ) {

            val result = pendingResult

            pendingResult = null

            if (
                grantResults.isNotEmpty() &&
                grantResults[0] ==
                    PackageManager.PERMISSION_GRANTED
            ) {

                sendSmsNow(
                    pendingPhoneNumbers,
                    pendingMessage,
                    result ?: return
                )

            } else {

                result?.error(
                    "SMS_PERMISSION_DENIED",
                    "SMS permission was denied.",
                    null
                )
            }

            pendingPhoneNumbers =
                emptyList()

            pendingMessage = ""

            return
        }

        // Phone-call permission
        if (
            requestCode ==
            callPermissionRequestCode
        ) {

            val result =
                pendingCallResult

            pendingCallResult = null

            val phoneNumber =
                pendingCallNumber

            pendingCallNumber = null

            if (
                grantResults.isNotEmpty() &&
                grantResults[0] ==
                    PackageManager.PERMISSION_GRANTED
            ) {

                if (phoneNumber != null) {
                    placeCallNow(
                        phoneNumber,
                        result ?: return
                    )
                }

            } else {

                result?.error(
                    "CALL_PERMISSION_DENIED",
                    "Phone call permission was denied.",
                    null
                )
            }
        }
    }
}