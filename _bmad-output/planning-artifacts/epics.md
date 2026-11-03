---
status: current
source: _bmad-output/specs/spec-flutter-mobile-migration/SPEC.md
status_source: _bmad-output/implementation-artifacts/sprint-status.yaml
---

# TripC Flutter Hotel Booking — Epic and task breakdown

This breakdown follows the canonical migration spec. The sprint status file is the source for task progress; this file defines the current feature slices and completion conditions. Slides and demo preparation are tracked separately in `../../PROJECT_CHECKLIST.md`.

## Scope and delivery rules

- Build the native Flutter hotel-booking experience using the Next.js hotel flow as the product reference.
- Reuse existing API/Supabase access only where current auth and permissions support it. Do not add endpoints, change backend/schema/auth/RLS, or introduce server secrets into Flutter.
- Treat UI presence as implementation evidence only. A feature is complete when its supported data/auth path and required behavior work.
- Finish all scoped features first, then run acceptance, then package/install/verify the release APK.
- Flights, dining, events, shop, beauty, wellness, and online payment are out of scope.

## Epic 1 — Auth, profile, and preserved flow state

**Stories:** 1-1 register/sign-in; 1-2 session restore/auth guard/context; 1-3 view/update profile.

**Detailed specification:** `../specs/spec-flutter-mobile-migration/epic-1-auth-profile.md`.

**Complete when:** a supported existing session can sign in, restore, access profile, and log out; protected operations enforce the actual session; navigation preserves search and booking context. If current auth/RLS cannot support Flutter, record the blocker without adding backend work.

## Epic 2 — Hotel discovery, filters, map, and remote states

**Stories:** 2-1 keyword/date/guest/room search; 2-2 filter/sort/clear; 2-3 map/list selection; 2-4 loading/empty/error/retry.

**Complete when:** search and supported filters use existing hotel data, map uses real coordinates where present, and loading/empty/error/retry behavior is usable with recoverable state.

## Epic 3 — Hotel details, reviews, rooms, and rates

**Stories:** 3-1 gallery/content; 3-2 AI insight/reviews; 3-3 rooms/rate fallback; 3-4 room selection/reserve summary.

**Complete when:** hotel, review/aggregate, room, and rate content comes from supported existing sources; selected room and quote stay consistent through checkout. Do not invent review data, rates, or availability.

## Epic 4 — Guest details, price review, and pending booking

**Stories:** 4-1 guest form/draft; 4-2 booking summary/price breakdown; 4-3 create pending booking.

**Complete when:** guest values validate and survive back navigation; price rules match the existing web/backend behavior; a booking request succeeds only after the backend returns a real ID/status under the signed-in user's existing permissions. Display pending/unpaid accurately.

## Epic 5 — Booking history, detail, cancellation, and acceptance

**Stories:** 5-1 list/filter; 5-2 detail; 5-3 cancel pending; 5-4 acceptance and release packaging.

**Complete when:** users can only read/manage their own bookings and cancellation follows existing rules. Story 5-4 includes acceptance evidence only after all scoped features are implemented; build and verify a release APK only after acceptance passes.

## Epic 6 — Notifications, AI chat, and main navigation

**Stories:** 6-1 read/mark notifications; 6-2 start/continue AI chat; 6-3 add both to main navigation.

**Complete when:** notifications and chat work through their existing supported data/API path with the Flutter session, show actionable failure states, and are reachable through app navigation. If the current chat route requires an incompatible Clerk session, record the blocker.

## Cross-epic acceptance

- `dart format`, `flutter analyze`, and `flutter test` pass.
- Manual end-to-end checks use the real configured backend and supported user session.
- Check state preservation, loading/empty/error/retry, network loss, authorization/ownership, and pending/unpaid messaging.
- Record environment, device/emulator, scenarios, results, and limitations. Synthetic fixtures are not backend acceptance evidence.
- After acceptance passes, build/install the release APK and repeat the core flow on that artifact.
