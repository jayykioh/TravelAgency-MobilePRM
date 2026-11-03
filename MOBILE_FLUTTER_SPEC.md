# Flutter mobile migration — superseded source

**This path is retained as a pointer, not as an implementation contract.** The earlier v1.1 proposal for `/api/mobile/v1`, a separate JWT service, new migrations, `flutter_secure_storage`, and backend work is superseded and preserved only in Git history.

## Current source of truth

Use [`_bmad-output/specs/spec-flutter-mobile-migration/SPEC.md`](_bmad-output/specs/spec-flutter-mobile-migration/SPEC.md) and all companions linked in its frontmatter.

The agreed direction is to use the existing Next.js hotel experience as the UI/flow reference, rebuild the mobile client natively in Flutter, and connect only through existing backend APIs or Supabase access already supported by the project. Do not change backend routes, schema, auth, or access policies. If existing auth or permissions do not support a mobile operation, record a blocker instead of implementing a backend workaround.

Complete all features in the agreed mobile release scope before acceptance. After acceptance passes, build, install, and verify the release APK.
