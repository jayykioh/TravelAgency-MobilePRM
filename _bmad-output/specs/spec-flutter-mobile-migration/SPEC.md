---
id: SPEC-flutter-mobile-migration
companions: [api-contract.md, business-rules.md, architecture-and-state.md, ux-and-screens.md, delivery-and-quality.md]
---
# Flutter Hotel Booking Migration
## Why
Migrate giao diện và luồng Hotel Booking React/Next.js sang mobile/ trong 3 ngày, 4 người.
## Capabilities
- **CAP-1** — **intent:** Tái dùng data layer. **success:** SDK/API hiện hữu đọc ghi được bằng session thật.
- **CAP-2** — **intent:** Đăng ký/đăng nhập. **success:** Supabase Auth login/register/restore/logout đạt compatibility gate.
- **CAP-3** — **intent:** Tìm kiếm. **success:** Lọc city/ngày/số khách và trả kết quả thật.
- **CAP-4** — **intent:** Chi tiết/chọn phòng. **success:** Hiển thị loại phòng và giá từng đêm từ dữ liệu thật.
- **CAP-5** — **intent:** Nhập thông tin khách. **success:** Validate và giữ draft khi Back.
- **CAP-6** — **intent:** Review/tạo booking. **success:** Nhận ID thật và trạng thái pending.
- **CAP-7** — **intent:** Lịch sử/chi tiết. **success:** Đọc đúng đơn thuộc session hiện tại.
- **CAP-8** — **intent:** Điều hướng/state. **success:** Provider giữ criteria, room, draft qua auth guard.
- **CAP-9** — **intent:** P1 Map. **success:** Vị trí hiển thị khi P0 xong đúng hạn.
- **CAP-10** — **intent:** P1 Notifications. **success:** Đọc thông báo qua nguồn hiện hữu nếu P0 đúng hạn.
- **CAP-11** — **intent:** P1 Chat. **success:** API hiện hữu tương thích hoạt động nếu P0 đúng hạn.
- **CAP-12** — **intent:** Kiểm tra/đóng gói. **success:** Analyze/test đạt, APK cài và chạy 6 bước.
## Constraints
- Không viết/sửa backend, database, migration, seed, RLS hay auth server; không tạo /api/mobile/v1.
- Tái dùng Supabase SDK hoặc API/query web hiện hữu; chỉ publishable/anon key và session hợp lệ, không service-role.
- Chỉ đối chiếu Auth/Hotel Booking và dependency trực tiếp.
- Ngày 1 Auth + toàn bộ UI tĩnh; ngày 2 dữ liệu thật, P0 thông suốt 18:00; ngày 3 freeze 12:00, chiều test chéo/APK.
## Non-goals
Flights, Shop, Events, Dining, thanh toán online; slide/video/PDF/analyze-size; backend mới.
## Success signal
APK chạy login/register → search → detail/room → guest form → review/pending → history/detail bằng dữ liệu thật.
## Open Questions
Web được đối chiếu dùng Clerk. Supabase Auth và RLS hiện tại có cho session truy cập/tạo/đọc đơn không? Đây là blocker cần kiểm chứng, không được chuyển thành task backend.

