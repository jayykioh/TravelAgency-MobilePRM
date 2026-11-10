---
title: 'Sửa lỗi build Android do cache Kotlin'
type: 'bugfix'
created: '2026-11-06'
status: 'in-progress'
route: 'oneshot'
---

<frozen-after-approval>

## Intent

Kiểm tra code mới nhất trên origin/main và sửa lỗi không chạy được Android emulator. Giữ thay đổi local của người dùng. Tái hiện lỗi trước khi sửa và xác minh bằng build debug và khởi chạy emulator-5554.

</frozen-after-approval>

## Implementation Notes

- Fetch origin thành công; HEAD trùng origin/main tại thời điểm kiểm tra. Không cần merge.
- Build debug thất bại ở compileDebugKotlin của url_launcher_android và shared_preferences_android: Could not close incremental caches.
- Tắt Kotlin incremental compilation trong mobile/android/gradle.properties để tránh lỗi cache; không nâng dependency hay đổi toolchain.
- mobile/pubspec.lock là thay đổi có sẵn, không đưa vào bản sửa.
