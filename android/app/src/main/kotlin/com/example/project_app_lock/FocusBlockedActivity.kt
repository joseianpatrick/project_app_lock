package com.example.project_app_lock

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.ImageView
import android.widget.TextView

class FocusBlockedActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_focus_blocked)
        showBlockedApp(intent)
        findViewById<TextView>(R.id.return_home).setOnClickListener { returnHome() }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        showBlockedApp(intent)
    }

    private fun showBlockedApp(intent: Intent) {
        val packageId = intent.getStringExtra(EXTRA_BLOCKED_PACKAGE) ?: return
        try {
            val applicationInfo = packageManager.getApplicationInfo(packageId, 0)
            val appName = packageManager.getApplicationLabel(applicationInfo).toString()
            findViewById<ImageView>(R.id.blocked_app_icon).apply {
                setImageDrawable(packageManager.getApplicationIcon(applicationInfo))
                contentDescription = getString(R.string.blocked_app_icon_description, appName)
            }
            findViewById<TextView>(R.id.focus_blocked_title).text =
                getString(R.string.focus_blocked_app_title, appName)
        } catch (_: PackageManager.NameNotFoundException) {
            // Keep the generic artwork and title if the app is no longer installed.
        }
    }

    private fun returnHome() {
        startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME))
        finish()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        returnHome()
    }

    companion object {
        const val EXTRA_BLOCKED_PACKAGE = "blocked_package"
    }
}
