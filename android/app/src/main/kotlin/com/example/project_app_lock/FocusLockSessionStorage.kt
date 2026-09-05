package com.example.project_app_lock

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.provider.Settings

enum class FocusLockExternalPolicy(val channelValue: String) {
    SELECTED_ONLY("selected_only"),
    ALL_ELIGIBLE("all_eligible");

    companion object {
        fun fromChannelValue(value: String?): FocusLockExternalPolicy? =
            entries.firstOrNull { it.channelValue == value }
    }
}

object FocusLockSessionStorage {
    private const val PREFERENCES = "focus_lock_native_session"
    private const val PACKAGE_IDS = "package_ids"
    private const val ENDS_AT = "ends_at"
    private const val EXTERNAL_POLICY = "external_policy"

    // These packages and system-owned surfaces must always remain recoverable.
    private val safetyExcludedPackages = setOf(
        "android",
        "com.android.systemui",
        "com.android.settings",
        "com.android.permissioncontroller",
        "com.google.android.permissioncontroller",
        "com.android.packageinstaller",
        "com.google.android.packageinstaller",
        "com.android.emergency",
        "com.android.server.telecom",
        "com.android.phone",
    )

    fun save(
        context: Context,
        packageIds: Set<String>,
        endsAt: Long,
        policy: FocusLockExternalPolicy,
    ) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(PACKAGE_IDS, packageIds)
            .putLong(ENDS_AT, endsAt)
            .putString(EXTERNAL_POLICY, policy.channelValue)
            .apply()
    }

    fun shouldBlock(context: Context, packageId: String): Boolean {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val endsAt = preferences.getLong(ENDS_AT, 0L)
        if (endsAt <= System.currentTimeMillis()) {
            clear(context)
            return false
        }
        if (isSafetyExcluded(context, packageId)) return false
        return when (FocusLockExternalPolicy.fromChannelValue(preferences.getString(EXTERNAL_POLICY, null))) {
            FocusLockExternalPolicy.SELECTED_ONLY ->
                preferences.getStringSet(PACKAGE_IDS, emptySet()).orEmpty().contains(packageId)
            FocusLockExternalPolicy.ALL_ELIGIBLE -> isEligibleLaunchableThirdParty(context, packageId)
            null -> {
                // A malformed persisted value must fail open, never partially enforce.
                clear(context)
                false
            }
        }
    }

    fun reconcileExpiry(context: Context) {
        shouldBlock(context, "")
    }

    private fun isSafetyExcluded(context: Context, packageId: String): Boolean {
        if (packageId.isBlank() || packageId == context.packageName || packageId in safetyExcludedPackages) {
            return true
        }
        val packageManager = context.packageManager
        val recoverySurfacePackages = listOf(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
            Intent(Intent.ACTION_DIAL),
            Intent(Settings.ACTION_SETTINGS),
            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS),
        ).mapNotNull { intent ->
            packageManager.resolveActivity(intent, 0)?.activityInfo?.packageName
        }
        return packageId in recoverySurfacePackages
    }

    private fun isEligibleLaunchableThirdParty(context: Context, packageId: String): Boolean {
        val packageManager = context.packageManager
        return try {
            val info = packageManager.getApplicationInfo(packageId, 0)
            if (info.flags and ApplicationInfo.FLAG_SYSTEM != 0) return false
            val launcherIntent = Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .setPackage(packageId)
            packageManager.queryIntentActivities(launcherIntent, 0).any { resolveInfo ->
                resolveInfo.activityInfo.enabled && resolveInfo.activityInfo.exported
            }
        } catch (_: Exception) {
            // Package eligibility is uncertain: fail open rather than lock a recovery path.
            false
        }
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().clear().apply()
    }
}
