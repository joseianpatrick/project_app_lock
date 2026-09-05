# F06: External-app restriction

**Status:** Planned  
**Depends on:** F03, F04

## Goal

Apply the active session's external-app policy on Android and restore Focus Lock when the user opens a blocked app, without blocking safety-critical system surfaces or overstating kiosk-level control.

## Policy behavior

- Extend `SystemAppLockGateway.startLockSession` with a typed policy value:
  - `selectedOnly` when `allowOtherApps` is enabled.
  - `allEligible` when `allowOtherApps` is disabled.
- In `selectedOnly`, preserve existing behavior by blocking the task session's selected package IDs.
- In `allEligible`, block every eligible launchable third-party package discovered under the same eligibility rules used by app selection.
- Always exclude Focus Lock, System UI, launcher/system-critical packages, device settings, phone/emergency functionality, and permission/authorization surfaces.
- When the accessibility service detects a blocked package, bring Focus Lock to the foreground. Flutter's session restoration/router guard displays the active study screen.

## Native persistence and lifecycle

- Include the external-app policy in the method-channel request and persist it with package IDs and end time in native Android session storage.
- Restore the same policy after Flutter process death and device reboot.
- Expired sessions clear native policy before evaluating a package.
- Stopping or completing a session clears selected packages and the policy atomically from the native perspective.
- Add a typed native error for malformed/unsupported policy values; failed start must not leave Flutter session state active.

## Platform contract

- Keep Flutter and Android policy names mapped explicitly in the method-channel gateway; widgets never construct channel maps.
- Update the iOS handler for the extended `startLockSession` signature and continue returning `unsupported_platform` until an entitled Family Controls/Managed Settings implementation exists.
- Treat `allEligible` as best-effort focus enforcement, not device-owner kiosk mode. Do not claim that Home, Recents, notifications, power controls, or every system surface is disabled.
- Update accessibility disclosure, privacy documentation, and release review notes before distribution.

## Acceptance criteria

- Selected-only mode continues blocking exactly the configured distracting apps.
- All-eligible mode redirects an eligible unselected third-party app to Focus Lock.
- Safety exclusions remain accessible in both modes.
- The same behavior continues after process restart and Android reboot until expiry.
- Expiry and successful completion restore access without stale native state.
- Invalid native input fails safely and leaves no enforceable partial session.
- iOS returns a typed unsupported result without crashing or hanging the Flutter call.

## Test requirements

- Flutter gateway tests for typed policy serialization and platform errors.
- Android unit tests for storage, expiry, selected-only/all-eligible matching, exclusions, malformed values, clearing, and reboot restoration.
- Android integration/manual verification for foreground detection and returning to the active study screen.
- iOS channel tests for the extended request and unsupported response.
- Run Flutter tests, Android tests, and an APK build before marking complete.

## Safety constraints

- Never recursively block Focus Lock itself.
- Never use this feature to suppress emergency, phone, authorization, accessibility settings, or essential system recovery paths.
- If eligibility cannot be determined safely, allow the package and record/report the recoverable enforcement limitation.

