---
id: SPEC-flutter-mobile-migration
companions: [api-contract.md, business-rules.md, architecture-and-state.md, ux-and-screens.md, delivery-and-quality.md, epic-1-auth-profile.md, epic-3-hotel-detail-rooms-rates.md, epic-4-guest-checkout-pending-booking.md]
---
# Flutter Mobile Migration
## Why
Rebuild the selected Next.js travel-booking experience as a native Flutter mobile app while reusing the existing backend and data access.
## Capabilities
- **CAP-1** — **intent:** Reuse the existing data services. **success:** Flutter reads and writes through currently supported APIs or Supabase access using real credentials and permissions.
- **CAP-2** — **intent:** Authenticate and manage a user profile. **success:** Sign-in, registration, session restore, profile view/update, and logout work with an authentication method already supported by the backend.
- **CAP-3** — **intent:** Discover hotels. **success:** Search and filter by supported criteria and receive real backend data with loading, empty, and error states.
- **CAP-4** — **intent:** Compare hotel details and rooms. **success:** Hotel details, available rooms, rates, and map location use the selected hotel's real data.
- **CAP-5** — **intent:** Enter and preserve guest details. **success:** Required guest information validates and the draft survives back navigation.
- **CAP-6** — **intent:** Request a hotel booking. **success:** Booking uses existing backend rules and success is shown only after a real booking identifier is returned.
- **CAP-7** — **intent:** View and manage hotel bookings. **success:** A signed-in user can view their own bookings/details and perform cancellation supported by the existing backend.
- **CAP-8** — **intent:** Preserve flow state. **success:** Search criteria, selected hotel/room, and guest draft survive navigation and supported auth transitions.
- **CAP-9** — **intent:** Locate hotels. **success:** Map displays available hotel coordinates and opens an external map when supported.
- **CAP-10** — **intent:** Use notifications. **success:** The user can read and mark notifications using an existing supported data source.
- **CAP-11** — **intent:** Use the AI chat. **success:** The app sends a conversation to an existing compatible chat API and displays its response.
- **CAP-12** — **intent:** Accept and package the agreed mobile release scope. **success:** All scoped features are implemented, acceptance passes, then a release APK installs and runs through the required flow.
## Constraints
- Next.js UI and behavior are the product reference; Flutter implements native mobile layouts and interactions.
- Do not change the existing backend, APIs, database/schema, migrations, seed data, authentication services, or access policies; do not create mobile-specific endpoints.
- Connect only through backend APIs or Supabase SDK access and authentication/permissions already supported by the project; use no service-role or server secrets in Flutter.
- If an existing service does not support the mobile session or required operation, record a blocker; do not work around it with a backend change.
- Acceptance begins only after CAP-2 through CAP-11 are implemented; build/package and verify the APK only after acceptance passes.
## Non-goals
Migrating flights, dining, events, shopping, beauty, wellness, or other non-hotel services; adding online payment; changing or extending backend behavior.
## Success signal
The complete agreed mobile scope passes real-backend acceptance, then a release APK installs and demonstrates sign-in, hotel search, detail/room selection, pending booking, booking history, and the included map, notifications, and chat features.
## Open Questions
- Which currently supported auth/session path lets Flutter perform the required operations under existing backend permissions? This must be verified; backend changes are out of scope.
