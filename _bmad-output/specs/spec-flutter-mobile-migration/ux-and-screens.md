# Mobile UX and screen scope

## Product reference

Use the existing Next.js travel product as the source for hotel content, labels, business flow, and visual direction. Rebuild those experiences as native Flutter screens; do not embed the web app. Adapt navigation, controls, and page hierarchy for a phone screen while preserving the same data and booking semantics.

## Required screens and flows

1. Sign in/register and profile.
2. Hotel discovery with dates, guests, search, filters, sorting, and loading/empty/error states.
3. Hotel detail with images, description, reviews/amenities where available, room selection, rates, and map location.
4. Guest information and booking review.
5. Booking result with the real backend status and identifier.
6. Booking history, detail, and supported cancellation.
7. Notifications and AI chat, using existing project sources.

## Current Flutter screen inventory

`auth_screen.dart`, `profile_screen.dart`, `hotel_home_screen.dart`, `hotel_detail_screen.dart`, `hotels_map_screen.dart`, `hotel_checkout_screen.dart`, `hotel_bookings_screen.dart`, `notifications_screen.dart`, and `ai_chat_screen.dart` implement the current screen set. Their presence does not establish feature completeness or successful backend access.

## Interaction requirements

- Preserve search criteria and selected hotel/room when moving between screens or through supported authentication.
- Preserve guest form draft when returning from review or an auth interruption.
- Provide loading, empty, recoverable error, and retry states for remote operations.
- Make the pending/unpaid booking state clear; do not call it confirmed.
- Reuse the existing brand direction in `PROJECT_UI_STYLE.md` where applicable; adapt web patterns to native controls instead of copying desktop layouts literally.
