# TripC — TravelAgency Mobile PRM

This repository contains the existing Next.js travel platform and a native Flutter hotel-booking app built from its hotel flow.

## Current scope and status

- `mobile/`: Flutter client for auth/profile, hotel discovery, detail/rooms, map, checkout, bookings, notifications, and AI chat.
- `Project/`: existing web app and backend reference. Current mobile scope reuses existing backend behavior and access only; backend, schema, auth, and RLS changes are out of scope.
- `_bmad-output/specs/spec-flutter-mobile-migration/`: canonical requirements and implementation contract.
- `_bmad-output/implementation-artifacts/sprint-status.yaml`: story statuses and integration blockers.
- `PROJECT_CHECKLIST.md`: project-wide feature checklist, release gates, slide/demo tasks, and directory guide.
- `Project/docs/presentation.md`: presentation and demo preparation checklist.

## Run the Flutter app

See [`mobile/README-HOTELS.md`](mobile/README-HOTELS.md) for setup and required client-safe `--dart-define` values. Use only an existing supported user session and public client credentials; never place server secrets in Flutter.

## Release order

Complete all scoped features → run acceptance against the configured existing backend → build, install, and verify a release APK. A screen existing in the app is not proof that its backend integration passed.
