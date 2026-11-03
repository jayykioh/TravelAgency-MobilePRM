# TripC Flutter Hotel Booking — Presentation and demo checklist

**Current scope:** native Flutter hotel-booking app using existing backend access. This replaces the old broad SuperApp outline, which included unverified architecture, performance, and feature claims.

Track work in [`../../PROJECT_CHECKLIST.md`](../../PROJECT_CHECKLIST.md). Do not present a capability as complete unless the implementation and its evidence support the claim.

## Slides

- [ ] Cover: TripC, team/member names, course, and submission date.
- [ ] Problem and target user: travel booking flow being addressed.
- [ ] Project scope: Flutter hotel booking; state excluded modules explicitly.
- [ ] User journey: sign in → search/filter → hotel/room → guest/review → pending request → booking history.
- [ ] Supporting screens: map, notifications, AI chat, and profile; identify any integration limitations.
- [ ] Architecture: Flutter screens/provider/services → existing Supabase/API access; no new backend/API/schema work.
- [ ] Security and booking semantics: supported user session/RLS, pending/unpaid status, no claim of confirmed inventory.
- [ ] Implementation evidence: screenshots from the current app and source-backed feature status.
- [ ] Verification: list only tests, real-backend checks, and device runs actually completed, with device/environment.
- [ ] Known blockers and limitations: auth/RLS, booking ownership, notifications, chat compatibility, and price breakdown as applicable.
- [ ] Conclusion and Q&A; remove placeholders and unsupported claims.
- [ ] Proofread terminology, screenshots, names, links, and source attribution; export final deck/PDF.

## Live demo / recording

- [ ] Configure the approved demo URL and client-safe public Supabase settings; never expose service-role keys or server secrets.
- [ ] Prepare a test account and confirm the data/session works before presenting.
- [ ] Rehearse app launch and sign-in/profile.
- [ ] Rehearse hotel search, filters, detail, room/rate, and map.
- [ ] Rehearse guest details, review, pending booking result, and booking history/detail/cancel if the supported backend permits them.
- [ ] Show notifications and AI chat only if their existing data/API paths work with the demo session.
- [ ] Capture loading/empty/error/retry behavior and fallback recording/screenshots for network or environment failure.
- [ ] Confirm presentation device, screen mirroring, network, app build, and backup APK before demo time.
- [ ] Record demo date, device/build, scenarios completed, failures, and artifact location.
- [ ] Save final deck, PDF, demo recording, and evidence to the agreed delivery location; link it from `PROJECT_CHECKLIST.md`.

## Removed from the old outline

The former outline described an all-service SuperApp, Convex as the primary backend, a future React Native app, 40+ AI actions, online payment, event-driven architecture, and unverified performance/acceptance results. Those are not current Flutter migration commitments and must not be presented as project facts without fresh evidence.
