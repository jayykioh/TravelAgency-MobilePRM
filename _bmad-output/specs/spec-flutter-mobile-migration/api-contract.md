# Existing backend integration contract

## Rule

The existing Next.js/Supabase backend is reused as-is. Do not add mobile endpoints, alter existing routes, change database/schema/RLS/auth, add migrations, or create seed data. Flutter may call an existing API or use the existing Supabase SDK path only when that path already supports the user session and permissions required.

| Mobile need | Existing source to reuse | Current Flutter implementation / verification |
|---|---|---|
| Sign-in/register/profile | Existing project auth and profile behavior | Supabase Auth and profile screen exist in Flutter; compatibility with the current Clerk-based web identity and real RLS is unverified. |
| Hotel search | Existing hotel query/API and hotel data | `HotelService.searchHotels` queries `hotels`; live access and full criteria behavior need verification. |
| Hotel detail/rooms/rates | Existing hotel detail, room, and rate sources | Flutter reads `hotels`, `hotel_rooms`, `hotel_rates` (anon reads verified 2026-11-05). Live rates only cover 2026-01-27…2026-03-30, so current stays show labelled reference prices. |
| Hotel reviews / AI insight | Unified `reviews` table; public `POST /api/hotels/insights` | `hotel_reviews` (used by the web page) does not exist live; Flutter reads `reviews` by `entity_id`. Insight route is not Clerk-protected; end-to-end needs `APP_API_BASE_URL` and a running Next.js server. |
| Create pending booking | Existing booking operation and its business rules | Flutter inserts `hotel_bookings` with `user_uuid = external_user_ref = auth.uid()`, requires sign-in, and treats success only when an `id` is returned. Anonymous insert is rejected (401, verified). Signed-in insert depends on `users.id = auth.uid()` and RLS; unverified. |
| Booking history/cancel | Existing owner-scoped booking behavior | Flutter reads/updates `hotel_bookings`; verify access is bound to the signed-in owner and cancellation rules match the web. |
| Notifications | Existing notification source | Flutter queries `notifications`; verify the current session maps to the expected `user_id` and RLS. |
| AI chat | Existing `POST /api/chat/messages` | Flutter calls this route with the available Supabase access token; the route may require Clerk and return 401. Compatibility is unverified. |

## Integration gate

For each operation, document the exact existing endpoint/table, request and response shape, auth mechanism, and permission evidence. Validate against the real configured environment before marking the feature complete.

If an existing API rejects the available session, or existing Supabase permissions do not allow the operation, mark that feature blocked. Do not create a new API, policy, schema, auth flow, service-role path, or client-side ownership workaround. Resolve the blocker only through an already supported access path or an explicit future scope decision.
