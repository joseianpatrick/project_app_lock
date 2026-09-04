package com.example.project_app_lock

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED) {
            // Reading any package reconciles and clears an expired persisted session.
            FocusLockSessionStorage.isLocked(context, "")
        }
    }
}
