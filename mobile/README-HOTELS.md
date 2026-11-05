# TripC Hotels Flutter

App Flutter dựng lại native trải nghiệm Hotel Booking dựa trên UI/flow của Next.js. Scope hiện gồm Auth/Profile, Search/Filters, Detail/Rooms/Map, Guest Form/Review, booking pending/History, Notifications và AI Chat.
Không có Flights, Shop, Events, Dining, Transport hoặc Partner trong scope hiện tại.

Chạy:

Chạy nhanh bằng file cấu hình (khuyên dùng). Sao chép `env.example.json` thành `env.json` (đã gitignore) và điền các giá trị **client-safe**: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_API_BASE_URL`. Không đưa service-role key, Clerk secret, khóa thanh toán hoặc khóa AI vào file này:
```powershell
flutter run -d chrome --web-port=3000 --dart-define-from-file=env.json
```

Hoặc truyền cờ trực tiếp:
```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://dkviqhhjmdtqkfljhhuk.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY --dart-define=APP_API_BASE_URL=http://localhost:3000
```

Android debug: `flutter run` với cùng các `dart-define`. Chỉ build APK release sau khi toàn bộ feature scope hoàn thành và acceptance pass.

Không thay đổi backend/API/database/auth/RLS. Supabase Auth và RLS phải được project hiện hữu cho phép. Không dùng service-role key.
Web hiện dùng Clerk; SDK session Supabase chưa được kiểm chứng tương thích với policies thật. Chat route hiện hữu cũng có thể yêu cầu Clerk; nếu session Flutter không được chấp nhận thì ghi blocker, không tạo API mobile mới.
Code Flutter hiện ghi vào `hotel_bookings` và hiển thị pending/unpaid; schema, RLS và phản hồi ID thật cần xác minh trên backend hiện hữu. Không thanh toán, không giữ/trừ inventory, không bảo đảm chống oversell hoặc price validation phía server. Đây là yêu cầu đặt phòng, không phải xác nhận phòng.
Checkout tính thuế 10% và phí dịch vụ 5% trên tiền phòng, giống `BookingSidebar.tsx` và `checkout.service.ts` của web. Tiền phòng là tổng giá từng đêm của đối tác rẻ nhất phủ đủ đêm. Nếu không có rate cho đúng ngày, app hiển thị "Giá tham khảo" và ghi `metadata.rate_source`. Gửi yêu cầu đặt phòng bắt buộc đăng nhập.
Không thay đổi backend hoặc database để chạy app.
