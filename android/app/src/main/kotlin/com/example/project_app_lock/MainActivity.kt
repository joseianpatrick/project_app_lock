package com.example.project_app_lock

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.provider.Settings
import android.util.Base64
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_LOCK_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCapability" -> result.success(capability())
                "requestAuthorization" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(capability())
                }
                "getInstalledApps" -> loadInstalledApps(result)
                "startLockSession" -> startLockSession(call, result)
                "stopLockSession" -> {
                    FocusLockSessionStorage.clear(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun capability(): Map<String, Any> {
        val enabled = isAccessibilityServiceEnabled()
        return mapOf(
            "platform" to "android",
            "isAvailable" to enabled,
            "authorizationRequired" to !enabled,
            "reason" to if (enabled) {
                "Focus Lock accessibility access is enabled."
            } else {
                "Enable Focus Lock in Accessibility settings so it can detect and cover selected apps during a focus session."
            },
        )
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val manager = getSystemService(ACCESSIBILITY_SERVICE) as AccessibilityManager
        return manager.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_ALL_MASK,
        ).any { info ->
            info.resolveInfo.serviceInfo.packageName == packageName &&
                info.resolveInfo.serviceInfo.name == FocusLockAccessibilityService::class.java.name
        }
    }

    @Suppress("DEPRECATION")
    private fun loadInstalledApps(result: MethodChannel.Result) {
        try {
            val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val apps = packageManager.queryIntentActivities(launcherIntent, 0)
                .asSequence()
                .filter { it.activityInfo.packageName != packageName }
                .filter { resolveInfo ->
                    val flags = resolveInfo.activityInfo.applicationInfo.flags
                    flags and ApplicationInfo.FLAG_SYSTEM == 0
                }
                .filter { it.activityInfo.enabled && it.activityInfo.exported }
                .distinctBy { it.activityInfo.packageName }
                .map { resolveInfo ->
                    mapOf(
                        "packageId" to resolveInfo.activityInfo.packageName,
                        "displayName" to resolveInfo.loadLabel(packageManager).toString(),
                        "iconBase64" to drawableToBase64(resolveInfo.loadIcon(packageManager)),
                    )
                }
                .sortedBy { it["displayName"].orEmpty().lowercase() }
                .toList()
            result.success(apps)
        } catch (error: Exception) {
            result.error("installed_apps_failed", error.message, null)
        }
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888).also { bitmap ->
                val canvas = Canvas(bitmap)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
            }
        }
        val scaled = Bitmap.createScaledBitmap(bitmap, 64, 64, true)
        return ByteArrayOutputStream().use { output ->
            scaled.compress(Bitmap.CompressFormat.PNG, 90, output)
            Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
        }
    }

    private fun startLockSession(call: MethodCall, result: MethodChannel.Result) {
        if (!isAccessibilityServiceEnabled()) {
            result.error("authorization_required", "Accessibility access is required.", null)
            return
        }
        val packageIds = call.argument<List<String>>("packageIds").orEmpty().toSet()
        val endsAt = call.argument<Number>("endsAtEpochMillis")?.toLong()
        val policy = FocusLockExternalPolicy.fromChannelValue(
            call.argument<String>("externalAppPolicy"),
        )
        if (policy == null) {
            FocusLockSessionStorage.clear(this)
            result.error("invalid_external_policy", "A supported external app policy is required.", null)
            return
        }
        if (packageIds.isEmpty() || endsAt == null || endsAt <= System.currentTimeMillis()) {
            FocusLockSessionStorage.clear(this)
            result.error("invalid_session", "A non-empty app list and future end time are required.", null)
            return
        }
        FocusLockSessionStorage.save(this, packageIds, endsAt, policy)
        result.success(null)
    }

    private companion object {
        const val APP_LOCK_CHANNEL = "com.focuslock/app_lock"
    }
}
