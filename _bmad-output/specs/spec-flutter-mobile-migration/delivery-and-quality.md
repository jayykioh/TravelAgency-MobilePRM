# Completion, acceptance, and APK gates

Do not use the earlier three-day schedule as a release gate. The required order is feature completion, acceptance, then APK packaging.

## Gate 1 — Feature completion

Before acceptance starts, every feature in the agreed release scope must be implemented and connected to its supported existing data source:

- Auth/session and profile.
- Hotel search, filters, detail, rooms/rates, and map.
- Guest form, booking review/result, history/detail, and supported cancellation.
- Notifications and AI chat.

Each feature must have its normal, loading, empty, error, and auth/permission behavior. No feature is complete solely because a screen exists. Record any existing-backend compatibility blocker and stop; backend changes are out of scope.

## Gate 2 — Acceptance

Begin acceptance only after Gate 1 is complete. Acceptance evidence must include:

- `dart format` has no unformatted project files.
- `flutter analyze` passes.
- `flutter test` passes, including meaningful model and widget behavior.
- Manual end-to-end checks use the configured real backend and supported user session for sign-in/profile, search/detail/room, booking, history/cancellation, map, notifications, and chat.
- Verify navigation/back state, loading/empty/error/retry, loss of network, authorization/ownership, and pending/unpaid messaging.
- Record environment, device/emulator, scenarios, results, and any known limitation. A stubbed UI or synthetic fixture is not production/backend acceptance evidence.

Any failed required check returns the work to implementation/fix; acceptance has not passed.

## Gate 3 — APK

Only after Gate 2 passes, configure release signing, build the release APK, install it on an Android device or emulator, and repeat the core flow on that APK. Record the APK location, version/build number, signing/build result, device, and run result. A debug APK is not the release artifact.

## Out of scope

Changing backend/API/schema/auth/RLS, adding backend routes or migrations, online payment, and expanding Flutter to non-hotel travel categories.
