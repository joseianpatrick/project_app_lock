package com.example.project_app_lock

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class FocusLockAccessibilityService : AccessibilityService() {
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val foregroundPackage = event.packageName?.toString() ?: return
        if (foregroundPackage == packageName ||
            foregroundPackage == "com.android.systemui" ||
            !FocusLockSessionStorage.isLocked(this, foregroundPackage)
        ) return

        startActivity(
            Intent(this, FocusBlockedActivity::class.java).apply {
                putExtra(FocusBlockedActivity.EXTRA_BLOCKED_PACKAGE, foregroundPackage)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS,
                )
            },
        )
    }

    override fun onInterrupt() = Unit
}
