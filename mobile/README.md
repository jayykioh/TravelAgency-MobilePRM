# TripC Mobile (Flutter)

Native Flutter app for the agreed hotel booking migration. The existing Next.js UI and flows are the product reference; the app reuses existing backend APIs and Supabase access. Backend changes and new mobile endpoints are out of scope.

## Current feature scope

Auth/profile, hotel discovery and filters, detail/rooms/rates, map, booking request and history, notifications, and AI chat. A feature is complete only when its required existing data/auth path works, not when its screen is present.

## Setup

See [`README-HOTELS.md`](README-HOTELS.md) for the current Supabase configuration and run commands. Use only client-safe public credentials. Never pass a Supabase service-role key or server secret to Flutter.

## Canonical migration contract

Read [`MOBILE_FLUTTER_SPEC.md`](../MOBILE_FLUTTER_SPEC.md) for the supersession notice, then use [`spec-flutter-mobile-migration`](../_bmad-output/specs/spec-flutter-mobile-migration/SPEC.md) and its linked companions as the source of truth.

## Release order

Finish all scoped features → run and pass acceptance → build, install, and verify the release APK. Do not treat a debug APK or a screen-only implementation as acceptance evidence.
