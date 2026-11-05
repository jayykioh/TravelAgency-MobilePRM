# TripC Hotels Flutter

App Flutter dựng lại native trải nghiệm Hotel Booking dựa trên UI/flow của Next.js. Scope hiện gồm Auth/Profile, Search/Filters, Detail/Rooms/Map, Guest Form/Review, booking pending/History, Notifications, AI Chat, và Tcent Rewards / Voucher Hub (Lucky Day Spinner, Daily Streaks, Quests, Voucher Marketplace & Wallet).
Không có Flights, Shop, Events, Dining, Transport hoặc Partner trong scope hiện tại.

### Tcent Rewards & Vouchers Hệ thống:
- **Web Pages**: `/rewards` & `/vouchers`
- **Web API Endpoints**:
  - `GET /api/v1/gamification/spin` (Kiểm tra lượt quay miễn phí hôm nay: 1 lượt/24h)
  - `POST /api/v1/gamification/spin` (Quay thưởng ngẫu nhiên: 50 TC, 100 TC, 500 TC, 2K TC, 5K TC, 10K TC, JACKPOT Voucher)
  - `GET /api/v1/vouchers/marketplace` (Danh sách voucher có thể đổi bằng Tcent)
  - `POST /api/v1/vouchers/exchange` (Đổi voucher bằng điểm Tcent, ghi vào `user_vouchers` và `tcent_ledger`)
  - `GET /api/v1/vouchers/wallet` (Danh sách voucher đã sở hữu trong ví)
  - `GET /api/v1/user/status` (Số dư Tcent, hạng thành viên, điểm pending)
- **Tích hợp Mobile**:
  - `RewardsVouchersScreen`: Xem số dư, quay vòng quay may mắn, theo dõi chuỗi điểm danh và đổi voucher.
  - `hotel_checkout_screen.dart`: Chọn nhanh voucher từ ví khi đặt phòng.

Chạy:

Chạy nhanh bằng file cấu hình (khuyên dùng):
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
Màn checkout hiện tính thêm 10% thuế và 5% phí ở client; cần đối chiếu với logic giá hiện hữu của Next.js/backend trước khi xem là đúng nghiệp vụ.
Không thay đổi backend hoặc database để chạy app.
