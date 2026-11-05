# Epic 4 — Thông tin khách, xem lại giá và tạo booking pending

## Mục tiêu

Từ phòng đã chọn, người dùng nhập thông tin liên hệ (bản nháp được giữ lại), xem lại toàn bộ giá theo đúng quy tắc web, rồi gửi một **yêu cầu đặt phòng pending, chưa thanh toán** dưới phiên đăng nhập của chính họ. Chỉ báo thành công khi backend trả về ID thật.

## Phạm vi
- Form khách: họ tên, email, số điện thoại, yêu cầu đặc biệt, mã ưu đãi.
- Màn xem lại riêng (không còn là dialog): lưu trú, khách, giá từng đêm, tiền phòng, thuế, phí, tổng, cảnh báo giá tham khảo, trạng thái pending/unpaid.
- Insert `hotel_bookings` bằng Supabase SDK dưới session người dùng; màn kết quả.

Không bao gồm: thanh toán online, xác thực voucher qua `/api/v1/vouchers/validate` (route web cần Clerk), TCent/Working Pass, trừ `available_rooms`, gửi notification. Đây là các bước server-side của web mà Flutter không được tái tạo ở client.

## Quy tắc giá (đối chiếu web)
- `BookingSidebar.tsx` và `checkout.service.ts` (unified checkout) đều tính: **thuế 10% + phí dịch vụ 5% trên tiền phòng**. Flutter giữ đúng quy tắc này, tính bằng cents nguyên (`round`).
- Tiền phòng = tổng giá từng đêm của quote × số phòng (Epic 3).
- Mã ưu đãi chỉ được lưu `metadata.voucher_code` với `voucher_applied: false` và UI ghi rõ "chưa áp dụng vào tổng". App không tự trừ giảm giá.

## Story 4-1 — Form khách và giữ bản nháp

### Yêu cầu
- Validate phía client: tên 2–100 ký tự; email đúng định dạng; số điện thoại 8–15 chữ số (cho phép `+`, khoảng trắng, `-`, `.`); yêu cầu đặc biệt ≤ 500 ký tự.
- Mọi thay đổi ghi vào `HotelState.draft*`; quay lại từ màn xem lại hoặc màn đăng nhập vẫn giữ giá trị.
- Prefill email từ auth, tên/số điện thoại từ hồ sơ `users` nếu đọc được; lỗi đọc hồ sơ không chặn form.
- Chưa đăng nhập → banner giải thích cần đăng nhập để gửi yêu cầu, có nút đăng nhập; dữ liệu nhập vẫn giữ.
- Quote không còn khớp lưu trú → màn hướng dẫn chọn lại phòng.

### Tiêu chí chấp nhận
- Widget test: submit rỗng hiện lỗi; nhập rồi back → draft còn; mở lại form thấy giá trị cũ.

## Story 4-2 — Tóm tắt booking và bảng giá

### Yêu cầu
- Hiển thị khách sạn, phòng × số phòng, ngày, số đêm, người lớn/trẻ em, thông tin khách (có nút "Sửa").
- Bảng giá: từng đêm, tiền phòng, thuế (10%), phí dịch vụ (5%), tổng. Định dạng theo currency của rate.
- Banner "Giá tham khảo" khi quote không phải giá chính xác; banner "Chờ xác nhận · Chưa thanh toán…" luôn hiển thị.

### Tiêu chí chấp nhận
- Unit test: `(10000 + 12000) × 2 phòng = 44000`, thuế 4400, phí 2200, tổng 50600.
- Widget test: màn xem lại có dòng thuế, phí, pending/unpaid và cảnh báo giá tham khảo.

## Story 4-3 — Tạo booking pending an toàn

### Payload (`buildBookingPayload`)
- `user_uuid` = `external_user_ref` = `auth.currentUser.id`. Bắt buộc đăng nhập; không còn dùng `DEMO-…` guest ref.
- `hotel_id`, `room_id`, `partner_id` (null với giá tham khảo không có đối tác), `confirmation_code` (8 ký tự, cùng bảng chữ như web), ngày, thông tin khách, `guest_count {adults, children, rooms}`.
- `total_cents`, `nightly_rate_cents` (trung bình), `tax_cents`, `fees_cents`, `currency`, `status: pending`, `payment_status: pending`, `booking_source: mobile`.
- `metadata`: giá từng đêm, số phòng, tiền phòng, `rate_source` (`exact` / `fallback_rate` / `hotel_best_price`), voucher.
- Không gửi `nights_count` (cột generated/default).

### Hành vi
- Chống gửi trùng: nút khóa khi đang gửi, chặn back khi đang gửi; `confirmation_code` được **giữ nguyên qua các lần thử lại** của cùng yêu cầu. Nếu lần trước đã ghi nhưng mất phản hồi, unique constraint trả `23505` và app báo "có thể đã ghi nhận, kiểm tra Đơn của tôi" thay vì tạo đơn mới.
- `HotelService.createBooking` kiểm tra session khớp `user_uuid`, chỉ chọn lại các cột cần thiết và **ném lỗi nếu không có `id`**.
- Lỗi được ánh xạ thành thông báo tiếng Việt, không lộ payload backend: `42501` (RLS), `23503` (FK user/hotel/room), `23505` (trùng), `23502/23514/22P02` (dữ liệu), `PGRST301/303` và `AuthException` (phiên), lỗi mạng (cảnh báo có thể đã tạo).
- Thành công → xóa draft và quote, mở màn kết quả với mã xác nhận, mã đơn (ID thật), "Chờ xác nhận", "Chưa thanh toán", tổng; nút tới "Đơn của tôi".

### Tiêu chí chấp nhận
- Widget test: gửi một lần, payload có `user_uuid`, tổng 46000 cents, màn kết quả hiện `booking-123`. Lỗi RLS giữ người dùng ở màn xem lại, không lộ thông báo gốc, thử lại dùng cùng mã xác nhận.
- **Backend thật:** insert không kèm session bị từ chối (`42501`, đã kiểm 05/11/2026); app hiển thị "Backend hiện tại không cho phép phiên này tạo đơn (RLS). Đơn chưa được tạo." Insert với session đã đăng nhập **chưa được chứng minh**.
- Kiểm thử live 05/11/2026 (`mobile/test_live/epic34_live_test.dart`): payload từ quote thật có tổng = tiền phòng × 1.15, `status/payment_status = pending`, không có `nights_count`; guard phía app chặn khi chưa có session.

### Blocker còn mở
- **Nguyên nhân gốc (đã đối chiếu migrations):** `users.clerk_id` là `NOT NULL UNIQUE` và dòng `users` chỉ được web tạo bằng service-role sau Clerk (`Project/app/api/sync-user/route.ts`, Clerk webhook). Không có trigger nào từ `auth.users` sang `users`. Vì vậy tài khoản Supabase Auth trên mobile không có dòng `users`, insert hotel_bookings sẽ lỗi FK `23503` (hoặc `42501` nếu RLS chặn trước). Đây là quyết định backend (cầu nối Supabase Auth → `users`, RLS insert), nằm ngoài phạm vi app.
- Schema snapshot yêu cầu `hotel_bookings.user_uuid NOT NULL REFERENCES users(id)`. Insert chỉ thành công nếu `users.id` của người dùng **bằng** Supabase `auth.uid()` và RLS cho phép insert với session đó. Web hiện tạo booking bằng service-role server sau Clerk auth, nên cả hai điều kiện đều chưa được bảo đảm. Nếu thất bại, app báo lỗi `42501`/`23503` rõ ràng. Không sửa backend; ghi lại kết quả thử và giữ 4-3 ở trạng thái chặn cho đến khi có bằng chứng.

## Điều kiện hoàn tất Epic 4
- 4-1, 4-2 đạt tiêu chí và test pass.
- 4-3: một tài khoản thật đăng nhập trên app tạo được đơn và nhận ID thật; đơn đó xuất hiện trong "Đơn của tôi"; thử với tài khoản khác không đọc được đơn. Ghi môi trường, thiết bị, kết quả.

## Trạng thái hiện tại
- **4-1 — done.** **4-2 — done.**
- **4-3 — in-progress / blocked:** code hoàn chỉnh và có test, còn chờ bằng chứng insert thật với session đăng nhập (xem blocker).

## Source liên quan
- Flutter: `mobile/lib/screens/hotel_checkout_screen.dart` (`GuestDetailsScreen`, `BookingSummaryCard`), `mobile/lib/screens/booking_review_screen.dart` (`BookingReviewScreen`, `BookingResultScreen`), `mobile/lib/models/booking_request.dart`, `mobile/lib/providers/hotel_state.dart`, `mobile/lib/services/hotel_service.dart`.
- Web tham chiếu: `Project/components/checkout/forms/hotel-checkout-form.tsx`, `Project/lib/checkout/services/checkout.service.ts`, `Project/app/api/hotels/bookings/route.ts`, `Project/lib/hotel/utils.ts`.
- Test: `mobile/test/booking_request_test.dart`, `mobile/test/hotel_detail_checkout_flow_test.dart`.
