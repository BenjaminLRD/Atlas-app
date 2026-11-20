package com.atlasfitness.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by the health plugin to request
// Health Connect permissions (registerForActivityResult).
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "atlas/activity_recognition"
    private val requestCode = 7401
    private val permission = Manifest.permission.ACTIVITY_RECOGNITION
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(status())
                    "request" -> request(result)
                    "openSettings" -> {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null)
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // Activity Recognition is a runtime permission from Android 10 (API 29).
    // Before that the step counter needs no permission.
    private fun isGranted(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(this, permission) ==
            PackageManager.PERMISSION_GRANTED

    // Android reports "no rationale" both before the first request and after a
    // permanent refusal, so whether the dialog was already shown is remembered.
    private fun status(): String {
        if (isGranted()) return "granted"
        val asked = getSharedPreferences("atlas_steps", MODE_PRIVATE)
            .getBoolean("asked", false)
        val canAskAgain = ActivityCompat.shouldShowRequestPermissionRationale(this, permission)
        return if (asked && !canAskAgain) "permanentlyDenied" else "denied"
    }

    private fun request(result: MethodChannel.Result) {
        if (isGranted()) {
            result.success("granted")
            return
        }
        if (pendingResult != null) {
            result.error("busy", "A permission request is already open", null)
            return
        }
        pendingResult = result
        getSharedPreferences("atlas_steps", MODE_PRIVATE)
            .edit().putBoolean("asked", true).apply()
        ActivityCompat.requestPermissions(this, arrayOf(permission), requestCode)
    }

    override fun onRequestPermissionsResult(
        code: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(code, permissions, grantResults)
        if (code == requestCode) {
            val result = pendingResult
            pendingResult = null
            result?.success(status())
        }
    }
}
