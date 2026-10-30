# TripC Hotels Flutter

Chỉ migrate Hotel Booking: Auth, Search, Detail/Rooms, Guest Form, Review, pending booking và History.
Không có Flights, Shop, Events, Dining, Transport hoặc Partner trong app.

Chạy:

flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY

Android: flutter build apk --debug với cùng hai dart-define.

Supabase Auth và RLS phải được project hiện hữu cho phép. Không dùng service-role key.
Web hiện dùng Clerk; SDK session Supabase chưa được kiểm chứng tương thích với policies thật.
Booking dùng bảng bookings hiện hữu, pending/unpaid; không thanh toán, không giữ/trừ inventory,
không bảo đảm chống oversell hoặc price validation phía server. Đây là yêu cầu đặt phòng,
không phải xác nhận phòng. Giá hiển thị hiện là tổng nightly rates, chưa có breakdown thuế/phí.
Không thay đổi backend hoặc database để chạy app.
