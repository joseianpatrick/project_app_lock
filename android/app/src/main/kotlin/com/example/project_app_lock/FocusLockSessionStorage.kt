package com.example.project_app_lock

import android.content.Context

object FocusLockSessionStorage {
    private const val PREFERENCES = "focus_lock_native_session"
    private const val PACKAGE_IDS = "package_ids"
    private const val ENDS_AT = "ends_at"

    fun save(context: Context, packageIds: Set<String>, endsAt: Long) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(PACKAGE_IDS, packageIds)
            .putLong(ENDS_AT, endsAt)
            .apply()
    }

    fun isLocked(context: Context, packageId: String): Boolean {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val endsAt = preferences.getLong(ENDS_AT, 0L)
        if (endsAt <= System.currentTimeMillis()) {
            clear(context)
            return false
        }
        return preferences.getStringSet(PACKAGE_IDS, emptySet()).orEmpty().contains(packageId)
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().clear().apply()
    }
}
