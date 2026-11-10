# Supabase notifications

The Flutter inbox uses Supabase's table stream: initial read followed by database
INSERT/UPDATE/DELETE events, scoped to `auth.currentUser.id`, newest first, up to
50 rows. The unread count describes these loaded rows, not the entire history.
The stream is retained across rebuilds, cancelled on sign-out/account switch or
screen disposal, and restarted on app resume or manual refresh. The SDK reloads
the inbox after a reconnect. Read actions wait for a refresh and report failures.
An empty inbox can also be pulled to refresh.

## Database setup (required once per environment)

Run `../Project/supabase/notifications_realtime_setup.sql` in the SQL Editor of
the project referenced by the app's SUPABASE_URL. It is an explicit setup script,
not a CLI migration-history entry. It has not been applied to a live project by
this change. It creates the documented table if absent, checks its columns,
enables RLS, limits clients to reading their own rows/updating `is_read`, and adds
the table to `supabase_realtime`. Existing incompatible schemas cause a rollback.

The local app configuration currently targets project `dkviqhhjmdtqkfljhhuk`.
The connected Supabase account denied access to that project during implementation,
so live schema/permissions and delivery have not been verified. After applying the
setup, check the following before the acceptance steps:

```sql
select relrowsecurity from pg_class
where oid = 'public.notifications'::regclass; -- true

select * from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public' and tablename = 'notifications'; -- one row

select policyname, permissive, roles, cmd, qual, with_check
from pg_policies where schemaname = 'public' and tablename = 'notifications';
```

Notification records must use the recipient's **Supabase Auth UID** as `user_id`.
Trusted booking/reward producers must write that same ID. A Clerk identity or a
separate users-table ID must not be substituted without an explicit identity map.
Creation of notifications on business events remains the producer's job; the
inbox does not invent records. This provides live in-app updates while the app
is running; it does not provide OS notifications when the app is terminated.

## Acceptance against the configured backend

1. Sign in as A and open Notifications. In SQL Editor, insert a `system` row
   with A's Supabase Auth UID, title, and message. It should appear without refresh.
2. Change its message/is_read in SQL Editor. Verify text, unread dot, unread
   filter and loaded unread count update. Delete it and check it disappears.
3. Use a second signed-in A session; mark one/all as read and check both sessions.
4. Insert for user B. A must not receive or read B's row. Using A's authenticated
   client, SELECT/UPDATE B's id must return no rows; changing user_id/title/message
   or INSERT/DELETE must be denied. Guests must not read the inbox.
5. Sign out, then sign in as B. A's rows must disappear immediately. Repeat with
   a delayed network response; old rows must never reappear.
6. Disconnect/reconnect the network and background/resume the app. Check recovery,
   error/retry states, and pull-to-refresh even when the selected filter is empty.

References: [Dart stream](https://supabase.com/docs/reference/dart/stream),
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).
