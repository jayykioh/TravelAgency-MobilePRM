# TripC Hotels Flutter

App Flutter dựng lại native trải nghiệm Hotel Booking dựa trên UI/flow của Next.js. Scope hiện gồm Auth/Profile, Search/Filters, Detail/Rooms/Map, Guest Form/Review, booking pending/History, Notifications và AI Chat.
Không có Flights, Shop, Events, Dining, Transport hoặc Partner trong scope hiện tại.

Chạy:

flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY --dart-define=APP_API_BASE_URL=https://YOUR_EXISTING_NEXTJS_HOST

Android debug: `flutter run` với cùng các `dart-define`. Chỉ build APK release sau khi toàn bộ feature scope hoàn thành và acceptance pass.

Không thay đổi backend/API/database/auth/RLS. Supabase Auth và RLS phải được project hiện hữu cho phép. Không dùng service-role key.
Web hiện dùng Clerk; SDK session Supabase chưa được kiểm chứng tương thích với policies thật. Chat route hiện hữu cũng có thể yêu cầu Clerk; nếu session Flutter không được chấp nhận thì ghi blocker, không tạo API mobile mới.
Code Flutter hiện ghi vào `hotel_bookings` và hiển thị pending/unpaid; schema, RLS và phản hồi ID thật cần xác minh trên backend hiện hữu. Không thanh toán, không giữ/trừ inventory, không bảo đảm chống oversell hoặc price validation phía server. Đây là yêu cầu đặt phòng, không phải xác nhận phòng.
Màn checkout hiện tính thêm 10% thuế và 5% phí ở client; cần đối chiếu với logic giá hiện hữu của Next.js/backend trước khi xem là đúng nghiệp vụ.
Không thay đổi backend hoặc database để chạy app.
