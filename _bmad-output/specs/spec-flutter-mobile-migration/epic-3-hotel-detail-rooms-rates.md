# Epic 3 — Chi tiết khách sạn, đánh giá, phòng và giá

## Mục tiêu

Người dùng xem đầy đủ thông tin một khách sạn, đọc AI insight và đánh giá thật, so sánh các phòng phù hợp với số khách/số phòng, thấy giá đúng nguồn dữ liệu hiện hữu và chọn một phòng để sang checkout. Phòng và báo giá đã chọn phải nhất quán xuyên suốt checkout. Không bịa review, giá hay tình trạng phòng trống.

## Phạm vi

- Gallery ảnh, tên, hạng sao, loại hình, địa chỉ (jsonb `hotels.address`), mô tả, tiện ích, chính sách (jsonb `hotels.policies`).
- AI insight qua route web hiện hữu `POST /api/hotels/insights` (public, không cần Clerk).
- Đánh giá từ bảng hợp nhất `reviews` (`entity_id = hotels.id`, `status = 'published'`) và aggregate `hotels.average_rating` / `hotels.review_count`.
- Danh sách phòng `hotel_rooms` đang `active`, đủ sức chứa mỗi phòng; giá từ `hotel_rates`.
- Chọn phòng, reserve bar hiển thị tổng (gồm thuế, phí), đổi ngày/số khách ngay trên màn chi tiết.

Không bao gồm: viết review, yêu thích/chia sẻ, so sánh giá đối tác, giữ phòng/trừ inventory, sửa backend/schema/RLS.

## Nguồn dữ liệu đã xác minh (Supabase thật, anon key, 05/11/2026)

| Nguồn | Kết quả |
|---|---|
| `hotels` | Đọc được; có `address` jsonb (lat/lng/city/line1), `best_price` (cents), `average_rating`, `review_count`, `policies`, `property_type`. |
| `hotel_rooms` | Đọc được theo `hotel_id`, `status`, `capacity`. |
| `hotel_rates` | Đọc được; ~28.950 dòng, ngày từ 2026-01-27 đến 2026-03-30. Ngày hiện tại không có rate → app dùng giá tham khảo. |
| `hotel_reviews` | **Không tồn tại** trên DB thật (PGRST205), dù trang web vẫn query bảng này. |
| `reviews` | Tồn tại, có `entity_id`, `rating`, `title`, `comment`, `status`; anon đọc ra rỗng cho khách sạn đã thử. |
| `/api/hotels/insights` | Không bị Clerk middleware chặn. Chưa chạy end-to-end vì Next.js local không chạy lúc kiểm tra. |

## Story 3-1 — Gallery và nội dung chi tiết

### Yêu cầu
- Gallery vuốt ngang, bộ đếm ảnh, chạm để xem toàn màn hình (zoom). Ảnh lỗi hoặc thiếu → ảnh dự phòng, không vỡ layout.
- Tên, hạng sao, loại hình, địa chỉ đọc được từ jsonb; mô tả dài có "Xem thêm".
- Tiện ích và chính sách chỉ hiển thị khi có dữ liệu; key chính sách được dịch nhãn (Nhận phòng, Trả phòng…).
- Không còn nút "yêu thích/chia sẻ" không có chức năng.

### Tiêu chí chấp nhận
- Địa chỉ jsonb hiển thị dạng `line1, line2, city, country`, không in raw map.
- Khách sạn không có ảnh/mô tả/tiện ích vẫn hiển thị đúng, không có section rỗng.

## Story 3-2 — AI insight và reviews

### Yêu cầu
- Gọi `POST {APP_API_BASE_URL}/api/hotels/insights` với dữ liệu khách sạn + ngày + số khách; có loading, lỗi + thử lại, và thông báo riêng khi thiếu `APP_API_BASE_URL`.
- Nội dung AI có nhãn "Nội dung do AI tạo, chỉ mang tính tham khảo". Không còn câu insight hard-code.
- Reviews: tối đa 10 review mới nhất (`reviews`, `published`). Tóm tắt điểm ưu tiên aggregate của khách sạn khi `review_count > 0`, nếu không thì tính từ review đã tải. Không có dữ liệu → "Khách sạn chưa có đánh giá"; không hiển thị điểm mặc định.
- Lỗi đọc reviews có thông báo + thử lại, không ảnh hưởng phần còn lại của màn.

### Tiêu chí chấp nhận
- Không bao giờ hiển thị rating/review không có trong backend (test `review summary never invents a rating`).
- Insight lỗi/thiếu cấu hình không chặn chọn phòng.

## Story 3-3 — Phòng và fallback giá

### Quy tắc báo giá (`buildRoomQuote`)
1. **Giá chính xác:** chọn đối tác (`partner_id`) rẻ nhất có rate cho **mọi đêm** trong `[check-in, check-out)`, `available_rooms ≥ số phòng`, `min_nights ≤ số đêm`, cùng một currency. Tiền phòng = tổng giá từng đêm × số phòng (khớp `/api/hotels/bookings` của web).
2. **Giá tham khảo (rate gần nhất):** nếu không có đối tác phủ đủ đêm → lấy rate rẻ nhất ở ngày gần nhất có dữ liệu, áp cho mỗi đêm, gắn nhãn "Giá tham khảo".
3. **Giá tham khảo (best price khách sạn):** phòng không có rate nào → `hotels.best_price` (USD cents), như sidebar web.
4. Không có nguồn nào → "Chưa có giá cho phòng này", không cho chọn.

- Phòng lọc theo `capacity ≥ ceil(tổng khách / số phòng)`.
- Hai truy vấn rate: theo khoảng ngày lưu trú và rate gần nhất (tránh giới hạn 1000 dòng của PostgREST).
- Banner giải thích khi có giá tham khảo: phòng trống chưa được xác nhận.
- Nhãn bữa sáng/hoàn hủy chỉ hiển thị cho giá chính xác.

### Tiêu chí chấp nhận
- Unit test bao phủ: đối tác rẻ nhất phủ đủ đêm, thiếu đêm → fallback, thiếu phòng trống/min nights → fallback, không rate → best price, không gì cả → null, đêm qua tháng.
- Không còn giá mặc định tự đặt (trước đây `10000` cents).

## Story 3-4 — Chọn phòng và reserve summary

### Yêu cầu
- Chọn phòng lưu `selectedHotel` + `selectedQuote` trong `HotelState`; thẻ phòng có viền/biểu tượng "Đã chọn".
- Reserve bar: tên phòng, tổng gồm thuế 10% + phí 5%, số đêm/phòng; nút "Đặt phòng" bị khóa khi chưa chọn.
- Đổi ngày/số khách/số phòng → tải lại phòng và **xóa báo giá cũ**; checkout từ chối quote không khớp lưu trú hiện tại.

### Tiêu chí chấp nhận
- Widget test: chọn phòng cập nhật reserve bar (`$460.00` cho 2 đêm × $200), đổi số phòng xóa lựa chọn.

## Điều kiện hoàn tất Epic 3
- 3-1…3-4 đạt tiêu chí, `flutter analyze` không có lỗi mới, test liên quan pass.
- Acceptance thật: mở chi tiết vài khách sạn với backend thật, chụp lại trạng thái giá tham khảo, insight chạy với `APP_API_BASE_URL` trỏ tới Next.js đang chạy.

## Trạng thái hiện tại
- **3-1, 3-3, 3-4 — done.** Đã làm lại theo quy tắc trên.
- **3-2 — review.** Code hoàn chỉnh. Còn thiếu bằng chứng insight end-to-end (cần chạy Next.js với `DEEPSEEK_API_KEY` phía server) và một khách sạn có review published để kiểm tra hiển thị.

## Source liên quan
- Flutter: `mobile/lib/screens/hotel_detail_screen.dart`, `mobile/lib/models/room_quote.dart`, `hotel_review.dart`, `hotel_insight.dart`, `mobile/lib/utils/hotel_format.dart`, `mobile/lib/services/hotel_service.dart` (`roomOptions`, `reviewsFor`, `hotelInsights`).
- Web tham chiếu: `Project/app/hotels/[id]/page.tsx`, `Project/components/hotels/{HotelContent,AIInsights,BookingSidebar}.tsx`, `Project/app/api/hotels/insights/route.ts`, `Project/app/api/hotels/bookings/route.ts`.
- Test: `mobile/test/room_quote_test.dart`, `mobile/test/hotel_detail_checkout_flow_test.dart`.
