# Flutter architecture and state

## Boundaries

Flutter is a native client. Next.js pages/components define the reference UI and behavior; they are not embedded in a WebView. Keep UI, state, and service access separate:

`Screens → Provider/ChangeNotifier → HotelService or focused services → existing Supabase SDK/API`

The current app uses Provider and `HotelService`. Screens should ask state/services for operations instead of issuing database/API requests directly. Do not add backend layers or packages unless needed to call an existing service.

## State to preserve

- Auth/session state and profile.
- Search city, dates, guests, room count, filters, and sort order.
- Selected hotel, selected room, and displayed rate.
- Guest form draft and booking result.
- Loading, empty, error, and retry state for remote data.

## Data access and secrets

- Reuse the existing Next.js API routes and existing Supabase SDK/database access only where the current backend already permits the operation.
- Use only client-safe Supabase URL/public key and a supported user session. Never put service-role keys, server secrets, or privileged credentials in the app.
- Keep auth and ownership checks consistent with the current backend. A demo/anonymous owner identifier is not proof of an authenticated user's access.
- If the current web API accepts only Clerk sessions and Flutter cannot obtain a supported session, stop that integration and report it as a blocker; do not add mobile auth or backend changes.

## Current implementation map

- `mobile/lib/screens/`: auth, hotel home/detail/checkout/history, map, profile, notifications, chat.
- `mobile/lib/providers/hotel_state.dart`: shared search and booking context.
- `mobile/lib/services/hotel_service.dart`: Supabase queries/mutations and existing chat API call.
- `mobile/lib/models/`: hotel, room, rate, review, and booking data types.

These paths show implemented client code, not live integration evidence. The release is complete only when each scoped feature's source, auth, and error paths work against the existing backend.
