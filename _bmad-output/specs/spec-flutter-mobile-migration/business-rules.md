# Mobile business rules

- Keep search city, dates, guest count, room count, and filters through hotel detail and checkout.
- Keep hotel, room, rate, and booking data consistent with the existing backend sources. Do not invent schema fields, pricing rules, taxes, fees, or availability guarantees.
- Use the backend's existing validation and booking behavior. Show a successful booking only after receiving a real booking identifier and status.
- Present pending/unpaid bookings as requests awaiting confirmation; do not imply payment, confirmed inventory, atomic reservation, idempotency, or price validation unless the existing backend guarantees it.
- Preserve guest form values when navigating back. Validate required fields and prevent accidental duplicate taps while a request is pending.
- Booking history and cancellation must operate only on records the current authenticated user is authorized to access under existing backend rules.
- On missing auth, forbidden access, stale rates, unavailable inventory, network failure, or malformed data, show an actionable error and preserve recoverable form/search state.
- Never use a synthetic guest owner ID to claim authenticated ownership or bypass backend access rules.

# Next.js UI to Flutter feature mapping

Paths under `Project/` identify the web reference; Flutter paths identify the current native implementation.

| Web reference | Flutter implementation | Scope |
|---|---|---|
| `app/sign-in/`, `app/sign-up/`, `app/profile/` | `mobile/lib/screens/auth_screen.dart`, `profile_screen.dart` | Required |
| `app/hotels/`, hotel search/filter components | `hotel_home_screen.dart`, `filter_section.dart`, `hotel_card.dart` | Required |
| Hotel details, rooms, rates, reviews | `hotel_detail_screen.dart` and hotel models | Required |
| Hotel map/location UI | `hotels_map_screen.dart` | Required |
| `app/hotel/checkout/` and hotel checkout form | `hotel_checkout_screen.dart` | Required |
| `app/my-bookings/` | `hotel_bookings_screen.dart` | Required |
| Existing notifications UI/API | `notifications_screen.dart` | Required in current release scope |
| Existing AI chat UI/API | `ai_chat_screen.dart` | Required in current release scope |

Flutter should preserve the web flow and key content while adapting layout and interaction to mobile. The mapping is a scope guide, not evidence that backend integration or acceptance has passed.
