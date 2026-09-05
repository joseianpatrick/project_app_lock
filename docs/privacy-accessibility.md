# Accessibility and privacy disclosure

Focus Lock uses Android Accessibility access only while the user has started an active focus session. It observes foreground-window package identifiers to return Focus Lock when a configured distracting app opens. It does not read window text, keystrokes, credentials, messages, screenshots, contacts, or browsing content.

When “Allow other apps” is off, enforcement is best effort: eligible launchable third-party apps are returned to Focus Lock. It is not kiosk mode. Home, Recents, notifications, power controls, and many system surfaces remain outside the app’s control. Emergency, phone, permission, accessibility, settings, launcher, System UI, and recovery surfaces are explicitly excluded.

The active enforcement scope, selected package identifiers, and session end time are stored locally on-device so enforcement can recover after a Flutter process restart or device reboot. The state is cleared when the session ends or expires. No accessibility-event data is transmitted off-device.
