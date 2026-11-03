# TripC project checklist and directory guide

**Updated:** 2026-11-03  
**Current product focus:** native Flutter hotel-booking app in `mobile/`, using the existing Next.js/Supabase project without backend changes.

**Out of scope:** Flights, dining, events, shopping, beauty, wellness, online payments, and backend/API/schema/auth/RLS changes.

Epic 1 implementation contract: [`_bmad-output/specs/spec-flutter-mobile-migration/epic-1-auth-profile.md`](_bmad-output/specs/spec-flutter-mobile-migration/epic-1-auth-profile.md).

This is the project-wide status index. “Code exists” means there is an implementation in the repository; it does not mean real authentication, permissions, backend behavior, acceptance, or release has passed. The current sprint tracker is [`_bmad-output/implementation-artifacts/sprint-status.yaml`](_bmad-output/implementation-artifacts/sprint-status.yaml).

## Overall release status

- [ ] Finish every scoped feature and resolve or document supported existing-backend access for each one.
- [ ] Run acceptance after all scoped features are complete: format, analyze, tests, and real-backend end-to-end checks.
- [ ] Build, install, and verify a release APK only after acceptance passes.
- [ ] Prepare and review final presentation slides.
- [ ] Prepare and rehearse the live/demo recording or demo run; capture evidence and fallback screenshots/video.
- [ ] Verify the submitted slide/deck and demo artifacts are present in the repository or delivery location. No `.pptx`, `.pdf`, or `.mp4` artifacts were found in this checkout during this review.

## Feature and task checklist

Statuses below follow the sprint tracker and a source-file inventory. A **Done** story means the tracker records its implementation complete; the release gates above are still open.

| Area / task | Status | Current evidence or remaining work |
|---|---|---|
| Auth: register/sign in with Supabase Auth | Done in client | `auth_screen.dart` completed with form validation, safe error messaging, email verification guidance, and TripC visual design tokens. |
| Auth: restore session, guard routes, preserve context | Done in client | `hotel_state.dart` auth state stream listener, route guard helper, guest draft retention across navigations, clear separation between guest ID and authenticated user. |
| Profile view/update | Done in client | `profile_screen.dart` completed with full states (loading, guest preview, missing profile alert, error/retry, safe editing dialog preserving input on failure), read-only email, and verified fields. |
| Hotel keyword/date/guest/room search | Done in tracker | `hotel_home_screen.dart`, `hotel_state.dart`, `hotel_service.dart`; tracker says done. Real environment acceptance remains part of the release gate. |
| Hotel filters, sorting, clear filters | In progress | `filter_section.dart` exists; filter/sort behavior is not marked done in the tracker. |
| Hotel map/list selection | Done in tracker | `hotels_map_screen.dart` exists and story 2-3 is done. Confirm map data and external map handoff in acceptance. |
| Loading, empty, error, retry states | Done in tracker | Story 2-4 is done; acceptance must still exercise network and authorization failures. |
| Hotel details, gallery, amenities, policies | Done in tracker | `hotel_detail_screen.dart`; story 3-1 is done. |
| AI insight and reviews | In progress | Models and detail UI exist; actual review/aggregate source needs verification. |
| Rooms and rate fallback | Done in tracker | `hotel_service.dart`, `hotel_room.dart`, `hotel_rate.dart`; verify rate rules against existing backend data. |
| Room choice and reserve summary | Done in tracker | Detail screen and provider; story 3-4 is done. |
| Guest form and retained draft | In progress | `hotel_checkout_screen.dart` exists; finish draft/auth/back-navigation checks. |
| Checkout summary and price breakdown | Done in tracker | Checkout screen exists. Its client-side 10% tax and 5% service fee still require confirmation against current web/backend rules. |
| Create pending booking | In progress / blocked | Insert to `hotel_bookings` exists; production RLS, required schema, owner binding, real ID, and duplicate-submit behavior are unverified. |
| Booking list/filter | In progress | `hotel_bookings_screen.dart` exists; verify owner scoping and filters with a real session. |
| Booking detail | Done in tracker | Story 5-2 is done; verify access to another user's booking is denied. |
| Cancel pending booking | In progress / blocked | Update exists; confirm current-user ownership and backend cancellation rules. |
| Notifications and mark-read | In progress / blocked | `notifications_screen.dart` exists; verify schema, user mapping, and RLS. |
| AI chat and conversation continuation | In progress / blocked | `ai_chat_screen.dart` exists; `APP_API_BASE_URL` and compatibility of the existing Clerk-protected route with Flutter auth are unverified. |
| Main navigation for all required screens | Done in tracker | Story 6-3 is done; exercise every destination and return path. |
| Acceptance and release APK | In progress / not passed | Story 5-4 remains in progress. Do not mark release complete until feature work is complete, acceptance passes, and APK install/run is recorded. |
| Slides / presentation | Not evidenced / pending | Existing `Project/docs/presentation.md` was an inaccurate old SuperApp outline. It is now a task checklist; prepare a project-accurate deck and verify claims against code/evidence. |
| Demo / walkthrough | Not evidenced / pending | No final demo video or run record was found. Prepare a clean account/environment, rehearse the required flow, capture success and fallback evidence, and record any blocked backend operation honestly. |

### Blockers to close

- [ ] Prove the supported Flutter auth/session path works with existing auth and policies, or document the feature as blocked.
- [ ] Verify booking creation returns a real identifier and binds ownership under existing RLS.
- [ ] Verify booking history and cancellation are restricted to the signed-in owner.
- [ ] Verify notifications use the authenticated user's real identity and existing permissions.
- [ ] Verify the existing chat route accepts the Flutter session; configure `APP_API_BASE_URL` for the demo.
- [ ] Reconcile checkout price breakdown with the existing web/backend calculation.

## Directory guide

| Path | Contents and role |
|---|---|
| `mobile/` | Current native Flutter client and its Android/Web targets. |
| `mobile/lib/main.dart` | Flutter startup and app provider/bootstrap wiring. |
| `mobile/lib/screens/` | Auth, profile, discovery, detail, checkout, booking history, map, notifications, chat, and main shell screens. |
| `mobile/lib/providers/` | Shared app/search/booking state (`hotel_state.dart`). |
| `mobile/lib/services/` | Existing Supabase/API integration and hotel/booking operations (`hotel_service.dart`). |
| `mobile/lib/models/` | Hotel, room, rate, review, and booking data models. |
| `mobile/lib/widgets/` | Reusable hotel card/image, guest selector, and filter UI. |
| `mobile/test/` | Existing widget/model tests. Their presence is not evidence they passed in this review. |
| `mobile/android/` | Android app shell, Gradle configuration, launcher resources, and manifests. |
| `Project/` | Existing Next.js travel platform and backend reference. The current mobile work consumes its existing behavior/services; it is not the active Flutter implementation. |
| `Project/app/`, `Project/components/`, `Project/lib/` | Web routes, UI, and domain/client code used as reference for existing features and integrations. |
| `Project/supabase/` | Existing database migrations and Supabase project assets. Do not add or change backend schema/policies under the current mobile scope. |
| `Project/docs/` | Historical and feature-specific web documentation. Check its date and current code before treating it as authoritative. |
| `_bmad-output/specs/spec-flutter-mobile-migration/` | Canonical mobile migration contract: `SPEC.md` plus its five linked companions. |
| `_bmad-output/planning-artifacts/` | Current feature breakdown in `epics.md`, aligned to the canonical spec; task progress remains in the sprint tracker. |
| `_bmad-output/implementation-artifacts/` | Current story status, blockers, and task ownership tracker. |
| `PROJECT_UI_STYLE.md` | Existing visual reference adopted by the Flutter UX spec. |
| `PROJECT_PROGRESS.md` | Historical Shop Partner snapshot; not current Flutter migration status. |

## Canonical documents

1. [`_bmad-output/specs/spec-flutter-mobile-migration/SPEC.md`](_bmad-output/specs/spec-flutter-mobile-migration/SPEC.md) and linked companions: requirements and constraints.
2. [`_bmad-output/implementation-artifacts/sprint-status.yaml`](_bmad-output/implementation-artifacts/sprint-status.yaml): story-level task status and known integration blockers.
3. This file: project-wide checklist, slide/demo tasks, and directory guide.
4. [`Project/docs/presentation.md`](Project/docs/presentation.md): slide and demo preparation checklist.
