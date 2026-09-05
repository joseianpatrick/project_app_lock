# Release review: external-app restriction

Before Android distribution:

- Confirm the in-app accessibility disclosure matches [`privacy-accessibility.md`](privacy-accessibility.md) and the Android service description.
- Verify selected-only and all-eligible behavior on supported Android versions with the accessibility service enabled.
- Verify that emergency, phone, Settings, permission, accessibility, launcher, System UI, and Focus Lock remain accessible.
- Verify expiry, completion, Flutter process restart, and device reboot clear or restore the native session as intended.
- Review current Google Play Accessibility API policy and complete the required declaration before submission.
- Do not describe Focus Lock as kiosk mode or claim control of Home, Recents, notifications, or power controls.
