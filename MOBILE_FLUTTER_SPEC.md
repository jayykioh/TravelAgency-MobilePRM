# TripC Pro Mobile — Đặc tả triển khai Flutter cho nhóm

**Môn:** PRM393 – Mobile Application Development (Flutter), Project 30%
**Phiên bản:** 1.1 — 28/10/2026
**Đối tượng đọc:** toàn bộ thành viên nhóm. Đây là tài liệu làm việc: ai làm gì, làm theo hợp đồng nào, khi nào xong.
**Nguồn:** đề `PRM393_Project 1.docx`; mã trong `Project/` (Next.js) đã được rà ngày 28/10/2026 (mục 2).

> Quy ước: **[ĐÃ XÁC MINH]** = đã đọc trong code/migration. **[CẦN XÁC MINH]** = phải kiểm tra trên database/dịch vụ thật trước khi dựa vào. Không ghi vào báo cáo là "đã hoàn thành" khi chưa chạy và có minh chứng.

**Thay đổi so với 1.0** — giảm việc backend để dồn sức làm app Flutter:

- **Xác thực:** bỏ `clerk_flutter`. Mobile tự cấp JWT qua `/api/mobile/v1/auth/*`.
- **Đặt phòng:** bỏ luồng xác nhận lại giá trên UI, bỏ Idempotency-Key và retry ngầm. Thay hàm RPC plpgsql bằng code TypeScript trong route. Chỉ ghi phía `hotel_bookings`, không đồng bộ sang web.
- **Kiến trúc:** bỏ bản Fake repository và JSON fixtures trong `lib/`. Mock chỉ nằm trong `test/`, dùng `mocktail`.
- **P1:** chat trả JSON một lần; bản đồ chỉ hiện 1 marker.
- **Hiệu năng:** dùng ảnh chụp DevTools và bảng `--analyze-size` thay cho đo tay.

---

## 0. Tóm tắt 1 phút

- Làm **app Flutter mới** trong thư mục `mobile/` ở gốc repo. Không bọc website bằng WebView (Capacitor hiện có không tính là Flutter).
- Luồng lõi: **Đăng ký/Đăng nhập → Tìm khách sạn → Chi tiết & chọn phòng → Nhập thông tin → Xem lại & xác nhận → Đơn của tôi**.
- Kiến trúc: **MVVM + Provider**, repository, HTTP client `dio`.
- Backend: **tái dùng Next.js + Supabase của `Project/`** nhưng thêm một nhóm API riêng cho mobile `/api/mobile/v1/*`. Lý do: các API khách sạn hiện có không khớp schema thật và có lỗ hổng (mục 2).
- Xác thực: **JWT riêng cho mobile**. Server ký token sau khi đăng ký/đăng nhập; Flutter lưu bằng `flutter_secure_storage` và gửi `Authorization: Bearer <token>`. Không dùng Clerk ở phía mobile.
- Thanh toán **không** làm. Đơn tạo ra ở trạng thái `pending` / chưa thanh toán.
- Bắt buộc theo đề: ≥1 unit test, ≥1 widget test, release APK/AAB + bằng chứng chạy release, comment trong code, ZIP source + PDF báo cáo, slide demo 15 phút.

---

## 1. Đề bài yêu cầu gì (đọc từ docx)

| Hạng mục | Yêu cầu | Trọng số |
|---|---|---|
| Case study | Kịch bản kinh doanh thực tế, mạch lạc | 10% |
| Business analysis | Toàn bộ chức năng thiết kế theo quy tắc nghiệp vụ | 15% |
| System design | Kiến trúc, thiết kế database/API | 15% |
| Conclusion & discussion | Ý kiến cá nhân, kiến thức học được | 10% |
| **Demonstration** | Chương trình đúng thiết kế, chạy chất lượng | **50%** |

Yêu cầu kỹ thuật: UI, state management (Provider/Bloc/MVVM), database local hoặc remote, release APK/AppBundle, chứng minh chạy release mode, ≥1 unit test + ≥1 widget test, comment trong code. Demo phải trình bày chức năng, luồng state, xử lý dữ liệu, output test và **kết quả tối ưu hiệu năng**.

**"Project Sample"** trong đề liệt kê 10 chức năng, mỗi chức năng 10%: thiết kế DB/API, Login, danh sách, chi tiết, giỏ hàng, checkout, Notifications, Map, Chat, state management. Đây là mẫu cho đề tài cửa hàng. Ta ánh xạ sang đặt khách sạn ở mục 3.2. **Việc cần làm của trưởng nhóm:** hỏi giảng viên xem có chấm theo đúng 10 chức năng này không. Nếu có, các mục P1 (Map, Notifications, Chat) trở thành bắt buộc.

---

## 2. Kết quả rà code `Project/` (28/10/2026)

### 2.1. Hiện trạng chung

- `Project/` là web **Next.js 14 + TypeScript**, Zustand, Clerk, Supabase (Postgres, dùng service-role ở server), một phần Convex, cùng nhiều module: khách sạn, chuyến bay, shop, đối tác, sự kiện, ẩm thực, chat AI (DeepSeek), thanh toán MoMo/PayPal, thông báo đẩy. [ĐÃ XÁC MINH qua cấu trúc thư mục và `package.json`]
- `Project/android/` là Capacitor WebView tải `https://trip-c-remade.vercel.app`. **Không phải Flutter.** [ĐÃ XÁC MINH `capacitor.config.ts`]
- **Chưa có dự án Flutter nào trong repo.**
- Schema: `supabase/migrations/FINAL_TRIPC_SCHEMA.sql` (ghi "context only", giống bản dump) **khác** với các migration riêng lẻ. Ví dụ: migration tạo `hotel_bookings.user_id`, còn bản dump có `external_user_ref` + `user_uuid`; bản dump có `hotels.status` nhưng thiếu `best_price`. → **Không file nào chắc chắn là schema đang chạy.** [CẦN XÁC MINH trên Supabase thật]

### 2.2. Luồng đặt khách sạn mà web đang dùng thật

Web **không** gọi `POST /api/hotels/bookings`. Luồng thật là:

```
Trang khách sạn (đọc Supabase trực tiếp ở server component)
 → /hotel/checkout?hotelId&roomId&checkIn&checkOut&adults&children
 → POST /api/checkout/initialize   (ghi ledger `bookings`, status pending, unpaid)
 → POST /api/payments/create        (MoMo/PayPal)
 → webhook thanh toán → settlement  (lúc này mới tạo `hotel_bookings`)
```

### 2.3. Vấn đề phát hiện (ảnh hưởng trực tiếp đến mobile)

| # | Vị trí | Vấn đề | Hệ quả cho mobile |
|---|---|---|---|
| 1 | `app/api/checkout/initialize/route.ts` | **Không kiểm tra đăng nhập**; `userId` lấy từ body; `discountAmount` lấy từ client và được trừ thẳng vào tổng | Không dùng cho mobile: ai cũng có thể đặt thay người khác và tự giảm giá |
| 2 | `lib/checkout/services/checkout.service.ts` (nhánh hotel) | Giá = `hotels.best_price` cho **mọi phòng**, mặc định 840 USD nếu thiếu; không kiểm tra phòng trống; `start_date`/`end_date` của ledger ghi bằng **thời điểm hiện tại** thay vì ngày lưu trú | Không đáp ứng "server kiểm tra giá và khả dụng" |
| 3 | `app/api/hotels/bookings/route.ts` | Ghi các cột `user_id`, `nights`, `guest_info`, `base_price_cents`… **không có** trong bản dump; thiếu `booking_id` trong khi migration `20260130_harden_unified_pipeline.sql` đặt `hotel_bookings.booking_id NOT NULL`; truy vấn `hotels.title` trong khi cột là `name` | Gần như chắc chắn lỗi khi chạy. **Không dùng.** |
| 4 | cùng file trên | Client tự gửi `has_working_pass`, `user_tier`, `tcent_to_use`; số dư TCent bị gán cứng 10000; giảm tồn phòng không nằm trong transaction (race condition); không có idempotency; báo "Booking Confirmed!" khi đơn mới `pending` | Ví dụ điển hình cho phần "hạn chế" của báo cáo |
| 5 | `app/api/hotels/bookings/my-bookings/route.ts` | Lọc theo `user_id`, cột này không có trong bản dump (bản dump dùng `external_user_ref`/`user_uuid`) | Không dùng; viết endpoint mới |
| 6 | `app/api/hotels/[slug]/rates/route.ts` | Dùng `date <= end` (lấy cả đêm trả phòng); nếu khách sạn không có phòng thì **bỏ lọc phòng** và trả giá của mọi khách sạn | Viết lại logic báo giá trong API mobile |
| 7 | `app/api/hotels/route.ts` | Nhận `limit`/`offset` nhưng **không áp dụng** (`.range` không được gọi); `total` sai sau khi lọc tiện ích bằng JS; không lọc theo ngày/số khách | Cần endpoint danh sách có phân trang thật |
| 8 | `lib/hotel/clerkAuth.ts` | Dùng `auth()` của Clerk, vốn đọc phiên web; với request từ app native phải gửi Bearer token | Mobile không dùng Clerk; tự cấp JWT (mục 5.1) |

Những phần **dùng lại được**: bảng `hotels`, `hotel_rooms`, `hotel_rates`, `hotel_partners`, `hotel_bookings`, `bookings`, `users` (có `clerk_id`); `GET /api/bookings/[id]` (có kiểm tra chủ sở hữu); `GET/PATCH /api/v1/notifications` (có auth); `POST /api/chat/messages` (chat AI, có stream); `hotels.address` lưu `lat`/`lng` theo comment trong migration [CẦN XÁC MINH dữ liệu thật có tọa độ].

Lưu ý cho v1.1: `/api/v1/notifications` và `/api/chat/messages` xác thực bằng `auth()` của Clerk [ĐÃ XÁC MINH], nên **không nhận JWT mobile**. Mobile gọi các bản sao gọn trong `/api/mobile/v1` (mục 5.4) và chỉ tái dùng bảng cùng logic.

**Nguyên tắc:** không sửa các luồng web đang chạy. Mọi thay đổi backend cho mobile nằm trong `Project/app/api/mobile/v1/` và migration mới có tiền tố `*_mobile_*`. Web không cần hiển thị đơn tạo từ mobile.

---

## 3. Phạm vi sản phẩm

### 3.1. Vai trò người dùng

| Vai trò | Được làm |
|---|---|
| Khách (chưa đăng nhập) | Tìm kiếm, xem danh sách, xem chi tiết, xem bản đồ, xem giá |
| Người dùng đã đăng nhập | Như trên, cộng thêm: đặt phòng, xem đơn của mình, hồ sơ, thông báo, chat AI |

Tài khoản mobile **tách biệt** với tài khoản Clerk của web: người dùng web không đăng nhập mobile bằng mật khẩu cũ được. Đây là hạn chế đã chấp nhận và phải ghi vào báo cáo.

### 3.2. Danh sách chức năng và mức ưu tiên

| ID | Chức năng | Ưu tiên | Ánh xạ "Project Sample" |
|---|---|---|---|
| F01 | Thiết kế DB/API (tài liệu + migration + endpoint) | P0 | Design database/API |
| F02 | Đăng ký / đăng nhập / đăng xuất | P0 | Login screen |
| F03 | Tìm kiếm & danh sách khách sạn (thành phố, ngày, số khách, phân trang) | P0 | Product list |
| F04 | Chi tiết khách sạn, danh sách phòng, báo giá theo ngày | P0 | Product detail |
| F05 | Chọn phòng + form thông tin đặt | P0 | Shopping cart |
| F06 | Xem lại & xác nhận đặt (server tính giá) | P0 | Checkout/billing |
| F07 | Đơn của tôi + chi tiết đơn | P0 | — |
| F08 | Hồ sơ người dùng | P0 | — |
| F09 | Quản lý state bằng Provider (MVVM) | P0 | Apply state management |
| F10 | Bản đồ vị trí khách sạn (1 marker) | P1 | Map screen |
| F11 | Màn hình thông báo (đọc danh sách, đánh dấu đã đọc) | P1 | Notifications screen |
| F12 | Chat với trợ lý AI (JSON, không stream) | P1 | Messaging/chat |
| F13 | Wishlist, thanh toán MoMo sandbox, hủy đơn, đa ngôn ngữ | P2 | — |

- **P0** = bắt buộc để demo.
- **P1** = khuyến nghị mạnh, làm ngay sau khi P0 chạy ổn.
- **P2** = chỉ làm khi dư thời gian. Không đưa P2 vào báo cáo nếu chưa làm.

### 3.3. Quy tắc nghiệp vụ

| ID | Quy tắc | Kiểm tra ở |
|---|---|---|
| BR-01 | `check_in` ≥ hôm nay (múi giờ `Asia/Ho_Chi_Minh`); `check_out` > `check_in`; tối đa 30 đêm | Client + server |
| BR-02 | Khoảng lưu trú là nửa mở `[check_in, check_out)`. Nhận 10/11, trả 12/11 → 2 đêm, tính giá đêm 10 và 11 | Server |
| BR-03 | Người lớn 1–10, trẻ em 0–6; `adults + children ≤ capacity` và `adults ≤ max_adults`, `children ≤ max_children` của phòng | Client + server |
| BR-04 | Mỗi đêm phải có bản ghi `hotel_rates` cho đúng phòng và **cùng một partner**, `available_rooms > 0`, cùng tiền tệ | Server |
| BR-05 | Giá: `subtotal = Σ price_cents từng đêm`; `tax = round(subtotal × 10%)`; `fee = round(subtotal × 5%)`; `total = subtotal + tax + fee`. Tỷ lệ 10%/5% lấy theo web hiện tại, khai báo thành hằng số ở server | Server |
| BR-06 | Server **luôn tự tính lại giá từ DB** khi tạo đơn, không tin giá từ client. Client gửi `expected_total_cents`; nếu lệch → `409 PRICE_CHANGED` ("Giá đã thay đổi, vui lòng tải lại"). App hiện lỗi và đưa người dùng về HotelDetail để tải lại báo giá, **không** làm hộp thoại xác nhận giá mới | Server + client |
| BR-07 | Kiểm tra tồn phòng → tạo đơn → trừ `available_rooms` bằng code TypeScript trong route, không viết RPC. Hai người đặt cùng phòng cuối cùng cùng lúc vẫn có thể bán vượt; đây là **hạn chế đã biết**, ghi vào báo cáo | Server |
| BR-08 | Chống bấm đúp: nút "Xác nhận đặt" bị khóa ngay khi bấm (`isSubmitting`). Lỗi mạng/timeout → báo lỗi, cho bấm lại, gợi ý kiểm tra "Đơn của tôi" trước. Server không có idempotency key | Client |
| BR-09 | Họ tên 2–100 ký tự; email hợp lệ; số điện thoại VN `^(0|\+84)[0-9]{9,10}$`; yêu cầu đặc biệt ≤ 500 ký tự; mật khẩu ≥ 8 ký tự | Client + server |
| BR-10 | Đơn mới: `status = pending`, `payment_status = pending`. App ghi rõ "Chờ xác nhận – chưa thanh toán", **không** ghi "Đã xác nhận" | Client |
| BR-11 | Người dùng chỉ đọc được đơn của chính mình; đơn của người khác trả **404**, không trả 403, để không lộ việc đơn đó tồn tại | Server |
| BR-12 | Lưu snapshot giá, thông tin liên hệ và số khách vào đơn; thay đổi giá về sau không sửa đơn cũ | Server |
| BR-13 | MVP: đơn `pending` giữ phòng vô thời hạn. Chưa làm hủy hay hết hạn, phải ghi vào phần hạn chế | — |

---

## 4. Kiến trúc

### 4.1. Tổng thể

```
Flutter (mobile/)                      Next.js (Project/)                  Supabase Postgres
┌───────────────┐   HTTPS + Bearer   ┌──────────────────────────┐  service  ┌──────────────────┐
│ View (Widget) │ ─────────────────▶ │ /api/mobile/v1/*         │ ────────▶ │ users, hotels,   │
│ ViewModel     │       JWT          │  - auth: ký/verify JWT   │   role    │ hotel_rooms,     │
│ Repository    │ ◀───────────────── │  - validate (zod)        │           │ hotel_rates,     │
│ ApiClient(dio)│   JSON envelope    │  - tính giá, tạo đơn     │ ◀──────── │ hotel_bookings,  │
└───────────────┘                    └──────────────────────────┘           │ notifications    │
  flutter_secure_storage (lưu JWT)          │ chat: DeepSeek (JSON)         └──────────────────┘
```

- Flutter **không bao giờ** giữ service-role key, JWT secret hay DeepSeek key, và không truy cập Supabase trực tiếp.
- Base URL truyền lúc build: `--dart-define=API_BASE_URL=https://<deploy-của-nhóm>.vercel.app`. Không dùng `localhost` khi chạy trên điện thoại thật; với emulator dùng `http://10.0.2.2:3000` (chỉ khi debug).

### 4.2. Flutter: MVVM + Provider

| Lớp | Trách nhiệm | Không được làm |
|---|---|---|
| View (`*_screen.dart`, widget) | Vẽ UI theo state, gọi hàm của ViewModel | Gọi API, chứa quy tắc nghiệp vụ |
| ViewModel (`ChangeNotifier`) | Giữ state (`idle/loading/success/empty/error`), validate input, điều phối repository | Import `dio`, biết JSON |
| Repository | Gọi `ApiClient`, ánh xạ DTO → model, ném `AppException` | Biết widget |
| ApiClient (`dio`) | Base URL, timeout, gắn JWT, chuyển lỗi HTTP → `AppException`, 401 → đăng xuất | Biết nghiệp vụ |

- Trong `lib/` chỉ có **một** bản repository gọi API thật.
- ViewModel nhận repository qua constructor để test thay được bằng mock của `mocktail` (chỉ nằm trong `test/`).
- Khi backend chưa xong, làm UI trước rồi gắn API sau; không viết bộ dữ liệu giả trong `lib/`.

### 4.3. Cấu trúc thư mục `mobile/`

```text
mobile/
  lib/
    main.dart                      # đọc dart-define, chạy App
    app/
      app.dart                     # MaterialApp.router, theme
      router.dart                  # go_router + guard đăng nhập
      providers.dart               # MultiProvider: khởi tạo repo/VM
      theme.dart                   # màu, radius, typography (mục 7)
    core/
      config/env.dart              # API_BASE_URL
      network/api_client.dart      # dio + interceptors (gắn JWT, log, lỗi)
      network/api_exception.dart   # AppException + ErrorCode
      storage/token_storage.dart   # flutter_secure_storage: lưu/xóa JWT
      utils/date_utils.dart        # nights(), format, today theo VN
      utils/money.dart             # formatMinor(cents, currency)
      utils/validators.dart        # email, phone, name, password (BR-09)
      state/view_state.dart        # enum ViewState
    features/
      auth/          data/ domain/ presentation/   # AuthViewModel, Login, Register, Profile
      hotels/        data/ domain/ presentation/   # SearchVM, HotelListVM, HotelDetailVM (+ map 1 marker)
      booking/       data/ domain/ presentation/   # BookingViewModel, Form, Review, Result
      my_bookings/   data/ domain/ presentation/   # MyBookingsVM, BookingDetail
      notifications/ …                             # P1
      chat/          …                             # P1
    shared/widgets/               # AppButton, AppTextField, CardShell, StateView, PriceText
  test/
    mocks.dart                    # class MockXxxRepository extends Mock implements XxxRepository
    unit/                         # date_rules_test, validators_test, booking_vm_test
    widget/                       # search_screen_test, hotel_list_screen_test
  android/
  pubspec.yaml
  README.md                       # cách chạy, test, build release
```

### 4.4. Thư viện đề xuất

Dùng bản **stable mới nhất** lúc tạo dự án và commit `pubspec.lock`. Không thêm thư viện ngoài danh sách khi chưa được trưởng nhóm đồng ý.

**Flutter (`pubspec.yaml`):**

| Mục đích | Package |
|---|---|
| State | `provider` |
| Điều hướng | `go_router` |
| HTTP | `dio` |
| Lưu JWT an toàn | `flutter_secure_storage` |
| Định dạng ngày/tiền | `intl` |
| Ảnh | `cached_network_image` |
| Bản đồ (P1) | `flutter_map` + `latlong2` (OpenStreetMap, không cần API key) |
| Mở Google Maps ngoài (P1) | `url_launcher` |
| Icon | `lucide_icons_flutter` (khớp web) hoặc Material Icons |
| Test | `flutter_test`, `mocktail` (dev_dependencies) |

**Backend (`Project/package.json`):** thêm `jose` để ký/verify JWT. Băm mật khẩu bằng `crypto.scrypt` có sẵn của Node, không cần thêm thư viện. `zod` và `openai` (gọi DeepSeek) đã có sẵn [ĐÃ XÁC MINH].

---

## 5. Backend cho mobile

### 5.1. Thiết lập Auth JWT cho mobile (1 ngày, tuần 1)

Mục tiêu: app Flutter đăng ký, đăng nhập và gọi được endpoint có bảo vệ, không phụ thuộc Clerk.

1. **Schema:** bảng `users` trong bản dump có `clerk_id text NOT NULL UNIQUE`, `email` và không có cột mật khẩu [ĐÃ XÁC MINH trong `FINAL_TRIPC_SCHEMA.sql`; CẦN XÁC MINH trên DB thật]. Migration `*_mobile_auth.sql` thêm `password_hash text NULL` vào `users`. Khi đăng ký từ mobile, ghi `clerk_id = 'mobile_' || <uuid mới>` để thỏa ràng buộc NOT NULL UNIQUE mà không đụng tài khoản web.
2. **Server:** một file `lib/mobile/auth.ts` gồm `hashPassword` / `verifyPassword` (scrypt + salt), `signToken(userId)` (HS256, hết hạn 7 ngày) và `requireMobileUser(req)` (đọc `Authorization: Bearer`, trả `users.id` hoặc ném 401). Secret đặt trong biến môi trường `MOBILE_JWT_SECRET` (≥ 32 ký tự ngẫu nhiên, chỉ ở server).
3. **Endpoint:** `POST /auth/register`, `POST /auth/login`, `GET /me` (mục 5.4).
4. **Flutter:** lưu token bằng `flutter_secure_storage`; interceptor của `dio` gắn header cho mọi request; gặp 401 thì xóa token và chuyển về Login. Đăng xuất = xóa token trên máy. Token vẫn hợp lệ ở server đến khi hết hạn, đây là hạn chế đã chấp nhận.

**Tiêu chí xong:** đăng ký → đăng nhập → `GET /me` trả `200`; không token hoặc token sai trả `401`. Có ảnh chụp log làm minh chứng.

### 5.2. Chốt schema thật (tuần 1)

- Chạy truy vấn `information_schema.columns` cho các bảng `hotels`, `hotel_rooms`, `hotel_rates`, `hotel_partners`, `hotel_bookings`, `bookings`, `users`, `notifications` trên Supabase thật. Lưu kết quả vào `docs/mobile/schema-snapshot.md`.
- Đếm dữ liệu: số khách sạn, số phòng, số bản ghi `hotel_rates` cho 90 ngày tới, số khách sạn có `lat`/`lng`.
- Nếu thiếu dữ liệu: viết `supabase/seed/mobile_demo_seed.sql` (ví dụ 6–9 khách sạn ở Hà Nội, Đà Nẵng, TP.HCM; mỗi khách sạn 2–3 phòng; 1 partner `tripc-direct`; giá cho 120 ngày tới; có tọa độ). Seed phải chạy lại được (`ON CONFLICT DO NOTHING`).
- **Dùng project Supabase riêng của nhóm** cho demo nếu không có quyền ghi vào project gốc. Không dùng dữ liệu cá nhân thật.
- **Chọn nơi lưu đơn** dựa trên kết quả kiểm tra:
  - **(a) Mặc định:** dùng `hotel_bookings`. Nếu `booking_id` là `NOT NULL` và trỏ tới `bookings`, route tạo trước **một bản ghi tối giản** trong `bookings` (`category='hotel'`, `title`, `start_date`, `end_date`, `total_amount`, `currency`, `status='pending'`, `user_id`) chỉ để lấy `id`.
  - **(b) Nếu `hotel_bookings` có quá nhiều ràng buộc lệch so với bản dump:** tạo bảng mới `mobile_hotel_bookings` (khóa ngoại tới `users`, `hotels`, `hotel_rooms`, `hotel_partners`) chỉ với các cột ở mục 5.3.
  - M1 ghi lựa chọn và lý do vào `schema-snapshot.md`.

### 5.3. Tạo đơn trong `POST /api/mobile/v1/bookings` (TypeScript, không RPC)

Thứ tự xử lý trong route:

1. `requireMobileUser` → `userId`.
2. Validate body bằng `zod` (BR-01, BR-03, BR-09).
3. Lấy phòng (phải thuộc `hotel_id`, `status='active'`) và các bản ghi `hotel_rates` với `room_id`, `partner_id`, `date >= check_in AND date < check_out`.
4. Kiểm tra BR-02, BR-04; tính giá theo BR-05; so với `expected_total_cents` (BR-06) → lệch thì `409 PRICE_CHANGED`.
5. Ghi đơn theo phương án đã chọn ở 5.2. Các cột tối thiểu: `user_uuid` (= `users.id`), `hotel_id`, `room_id`, `partner_id`, `check_in_date`, `check_out_date`, `guest_name`, `guest_email`, `guest_phone`, `guest_count` (`{adults, children}`), `special_requests`, `total_cents`, `nightly_rate_cents` (= `round(subtotal / nights)`), `tax_cents`, `fees_cents`, `currency`, `status='pending'`, `payment_status='pending'`, `confirmation_code`, `booking_source='mobile'`.
6. Trừ `available_rooms` 1 cho từng đêm.
7. (P1) Ghi một dòng `notifications` "Đã ghi nhận yêu cầu đặt phòng <mã>" để màn Thông báo có dữ liệu [CẦN XÁC MINH cột của bảng `notifications`].
8. Trả `201` cùng đơn.

Nếu bước 6 hoặc 7 lỗi sau khi đã ghi đơn ở bước 5: ghi log, vẫn trả đơn, và ghi nhận đây là hạn chế (không có transaction). Code có comment giải thích điều này.

### 5.4. Hợp đồng API `/api/mobile/v1`

**Envelope chung**

```json
// thành công
{ "data": { ... }, "pagination": { "limit": 20, "offset": 0, "total": 57, "has_more": true } }
// lỗi
{ "error": { "code": "ROOM_UNAVAILABLE", "message": "Phòng đã hết vào 2026-11-10", "details": { } } }
```

- Ngày: `YYYY-MM-DD`. Tiền: số nguyên đơn vị nhỏ nhất (`*_cents`) kèm `currency`.
- Không trả stack trace hay lỗi SQL thô.

**Mã lỗi:**

| Code | HTTP |
|---|---|
| `VALIDATION_ERROR` | 400 |
| `INVALID_CREDENTIALS` | 401 |
| `UNAUTHENTICATED` | 401 |
| `NOT_FOUND` | 404 |
| `EMAIL_TAKEN` | 409 |
| `ROOM_UNAVAILABLE` | 409 |
| `PRICE_CHANGED` | 409 |
| `RATE_NOT_FOUND` | 409 |
| `INTERNAL` | 500 |

Tất cả đường dẫn dưới đây có tiền tố `/api/mobile/v1`. Cột "Auth" cho biết endpoint có cần `Authorization: Bearer <JWT>` hay không.

| # | Method & path | Auth | Input | Output chính |
|---|---|---|---|---|
| AU1 | `POST /auth/register` | — | `{ email, password, full_name, phone? }` | `201 { token, user }`; email đã có → `409 EMAIL_TAKEN` |
| AU2 | `POST /auth/login` | — | `{ email, password }` | `200 { token, user }`; sai → `401 INVALID_CREDENTIALS` (không nói rõ sai email hay sai mật khẩu) |
| A1 | `GET /me` | ✔ | — | `{ id, email, first_name, last_name, phone_number, image_url }` |
| H1 | `GET /hotels` | — | `city`, `q?`, `check_in?`, `check_out?`, `adults?`, `children?`, `limit=20`, `offset=0` | `[{ id, slug, name, city, address_line, star_rating, thumbnail, from_price_cents?, currency? }]` + pagination. Có ngày → `from_price_cents` là giá đêm thấp nhất còn phòng trong khoảng; không có ngày → `null` |
| H2 | `GET /hotels/{slug}` | — | — | `{ id, slug, name, description, address{line1, city, country}, lat?, lng?, star_rating, images[], amenities[], policies, rooms:[{ id, title, bed_type, capacity, max_adults, max_children, size_sqm, images[], amenities[] }] }` (chỉ phòng `status='active'`) |
| H3 | `GET /hotels/{slug}/quote` | — | `check_in`, `check_out`, `adults`, `children` | `[{ room_id, available: bool, reason?, partner_id, nights, nightly:[{date, price_cents}], subtotal_cents, tax_cents, fee_cents, total_cents, currency }]` cho từng phòng. Với mỗi phòng, chọn partner phủ đủ mọi đêm và có tổng thấp nhất |
| B1 | `POST /bookings` | ✔ | `{ hotel_id, room_id, partner_id, check_in, check_out, adults, children, guest:{full_name, email, phone}, special_requests?, expected_total_cents, currency }` | `201 { id, confirmation_code, status, payment_status, hotel{name}, room{title}, check_in, check_out, nights, guest_count, price:{subtotal, tax, fee, total, currency}, created_at }` |
| B2 | `GET /bookings` | ✔ | `limit`, `offset`, `status?` | Danh sách đơn của chính người dùng (shape B1 rút gọn) |
| B3 | `GET /bookings/{id}` | ✔ | — | Chi tiết như B1; không phải chủ → `404` |
| N1 | `GET /notifications` | ✔ | — | `[{ id, title, message, type, is_read, created_at }]`, đọc bảng `notifications` theo `user_id` (P1) [CẦN XÁC MINH tên cột] |
| N2 | `PATCH /notifications` | ✔ | `{ id }` hoặc `{ markAll: true }` | Đánh dấu đã đọc (P1) |
| C1 | `POST /chat` | ✔ | `{ messages:[{role, content}] }` (tối đa 10 tin gần nhất) | `{ reply: "..." }` — gọi DeepSeek qua thư viện `openai` với `stream: false`, trả **JSON một lần**. Không lưu lịch sử hội thoại trên server (P1) [CẦN XÁC MINH `DEEPSEEK_API_KEY` còn hoạt động] |

- Validation ở server dùng `zod`. Mỗi route có comment ghi rõ BR áp dụng.
- Flutter **không** parse SSE/stream.

---

## 6. Màn hình và state

### 6.1. Luồng điều hướng

```
Splash ──▶ Home/Search ──▶ HotelList ──▶ HotelDetail (có bản đồ 1 marker)
   │            │                             │
   │            └─ BottomNav: Search | My bookings | Notifications | Profile
   │                                          ▼
   └─▶ Login ⇄ Register ◀── (guard khi bấm "Đặt phòng") BookingForm ──▶ Review ──▶ Result ──▶ BookingDetail
```

- Splash: có token trong secure storage → gọi `/me`. Hợp lệ thì vào app ở trạng thái đã đăng nhập; 401 thì xóa token.
- Guard: các route `booking/*`, `my-bookings/*`, `profile`, `notifications`, `chat` cần đăng nhập. Sau khi đăng nhập, quay lại đúng màn đang dở; giữ nguyên tiêu chí tìm kiếm và phòng đã chọn.
- Nút Back của Android hoạt động trên mọi màn. Ở Result, Back về Home, không về Review, để tránh gửi lại.

### 6.2. Đặc tả từng màn

| Màn | Thành phần | State bắt buộc | Ghi chú |
|---|---|---|---|
| Login | Email, mật khẩu, nút "Đăng ký" | loading, error (sai thông tin, mạng), success | Không lưu mật khẩu, chỉ lưu JWT |
| Register | Họ tên, email, SĐT (tùy chọn), mật khẩu, nhập lại mật khẩu | lỗi theo trường (BR-09), `EMAIL_TAKEN`, success → vào app | |
| Search | Ô thành phố (gợi ý: Hà Nội, Đà Nẵng, TP.HCM, Hội An, Nha Trang, Phú Quốc, Đà Lạt), chọn khoảng ngày, stepper người lớn/trẻ em | lỗi theo trường (BR-01, BR-03) | Mặc định: nhận = mai, trả = ngày kia, 2 người lớn |
| HotelList | Card: ảnh, tên, sao, thành phố, "từ X/đêm" | loading (skeleton), loaded, empty ("Không có khách sạn phù hợp" + nút đổi tìm kiếm), error + Thử lại, tải thêm khi cuộn | `ListView.builder`, phân trang 20 |
| HotelDetail | Gallery, mô tả, tiện ích, chính sách, **bản đồ nhỏ** (`flutter_map`, 1 marker, không tương tác tìm kiếm) + nút "Mở Google Maps", danh sách phòng kèm báo giá H3 | loading, error, phòng hết (disable), thiếu giá; không có tọa độ → ẩn bản đồ | Đổi ngày ngay trên màn thì gọi lại H3 |
| BookingForm | Họ tên, email, SĐT (điền sẵn từ hồ sơ), số khách, yêu cầu đặc biệt | lỗi theo trường (BR-09) | Giữ dữ liệu khi quay lại |
| Review | Khách sạn, phòng, ngày, số đêm, giá từng đêm, thuế, phí, tổng, ghi chú "chưa thanh toán", nút "Xác nhận đặt" | idle, submitting (khóa nút + spinner), error | `PRICE_CHANGED` / `ROOM_UNAVAILABLE` → báo lỗi + nút "Tải lại chi tiết phòng". Timeout/mất mạng → báo lỗi + gợi ý kiểm tra "Đơn của tôi" trước khi bấm lại |
| Result | Mã đơn, trạng thái "Chờ xác nhận – chưa thanh toán", nút "Xem đơn" | — | Không hiệu ứng "Confirmed" |
| MyBookings | Tab Sắp tới / Đã qua; item: ảnh, tên, ngày, tổng, badge trạng thái | loading, empty, error, hết phiên → Login | Kéo để làm mới |
| BookingDetail | Toàn bộ snapshot, trạng thái đặt và trạng thái thanh toán tách riêng | loading, notFound, error | |
| Notifications (P1) | Danh sách, chấm chưa đọc, "Đánh dấu tất cả" | loading, empty, error | |
| Chat (P1) | Bong bóng chat, ô nhập, trạng thái "đang trả lời" | sending, error | Gọi C1, nhận cả câu trả lời một lần. Ghi rõ đây là trợ lý AI |
| Profile | Avatar chữ cái đầu, tên, email, SĐT, Đăng xuất (có hộp xác nhận) | loading, error | Đăng xuất: xóa JWT và mọi state riêng tư |

### 6.3. ViewModel và state

| ViewModel | State chính | Hành động |
|---|---|---|
| `AuthViewModel` (toàn app) | `unknown → unauthenticated / loading / authenticated(user) / error` | `restoreSession`, `login`, `register`, `logout` |
| `SearchViewModel` (toàn app) | `SearchCriteria{city, checkIn, checkOut, adults, children}` + lỗi theo trường | `update…`, `validate()` → bool |
| `HotelListViewModel` | `ViewState`, `items`, `hasMore`, `isLoadingMore` | `load(criteria)`, `loadMore()`, `retry()` |
| `HotelDetailViewModel` | `hotel`, `quotes`, `selectedRoomId` | `load(slug)`, `requote(criteria)`, `selectRoom` |
| `BookingViewModel` | `form`, `quote`, `isSubmitting`, `submitState: idle/submitting/success/error`, `errorCode`, `result` | `validateForm()`, `submit()` (thoát ngay nếu `isSubmitting == true`) |
| `MyBookingsViewModel` | `ViewState`, `upcoming`, `past` | `load()`, `refresh()` |

### 6.4. Model Dart (khớp hợp đồng 5.4)

```dart
class User    { String id, email; String? firstName, lastName, phone; }
class Hotel   { String id, slug, name, city; int? starRating; String? thumbnail; int? fromPriceCents; String? currency; }
class Room    { String id, title; int capacity, maxAdults, maxChildren; String? bedType; List<String> images; }
class Quote   { String roomId, partnerId, currency; bool available; String? reason; int nights, subtotalCents, taxCents, feeCents, totalCents; List<NightPrice> nightly; }
class Booking { String id, confirmationCode, status, paymentStatus, hotelName, roomTitle, currency;
                DateTime checkIn, checkOut, createdAt; int nights, adults, children, totalCents; }
```

Parse JSON trong `data/dto`. Tiền giữ dạng `int` (cents), chỉ định dạng ở UI qua `money.dart`.

---

## 7. Giao diện (theo `PROJECT_UI_STYLE.md` của web)

- Màu chính `#FF5E1F` cho nút và trạng thái active. **Không dùng xanh dương.** Thành công: emerald; lỗi: đỏ.
- Nền: sáng `#FCFAF8`, tối `#0A0A0A`; card trắng / `slate-900`. Hỗ trợ dark mode.
- Card bo góc 32, viền mảnh `slate-100`, bóng nhẹ. Nút và ô nhập dạng pill (bo tròn hoàn toàn).
- Chữ: tiêu đề đậm, nội dung `slate-600`. Animation ngắn (≤ 300 ms).
- Khai báo toàn bộ trong `app/theme.dart`; widget không được hard-code màu.

---

## 8. Phân công (3–5 thành viên)

| Vai trò | Phụ trách | Chức năng |
|---|---|---|
| **M1 – Trưởng nhóm / Backend** | Chốt schema + chọn nơi lưu đơn, seed, migration `password_hash`, toàn bộ route `/api/mobile/v1` (auth, hotels, quote, bookings, notifications, chat), deploy Vercel + Supabase của nhóm, review PR | F01, BE cho F02–F12 |
| **M2 – Core & Auth** | Khởi tạo `mobile/`, theme, router + guard, `ApiClient` + interceptor JWT, `token_storage`, Login/Register/Profile, widget dùng chung | F02, F08, F09 |
| **M3 – Hotels** | Search, HotelList, HotelDetail, báo giá, bản đồ 1 marker | F03, F04, F10 |
| **M4 – Booking** | BookingForm, Review, Result, MyBookings, BookingDetail, Notifications | F05, F06, F07, F11 |
| **M5 – QA / Docs** | Test (unit, widget với `mocktail`, thủ công), ảnh DevTools + bảng dung lượng APK, build release, báo cáo PDF, slide; màn Chat | F12, mục 9–11 |

- Nhóm 4 người: M5 chia việc cho cả nhóm; mỗi người tự viết test cho phần của mình, M1 lo báo cáo.
- Nhóm 3 người: gộp M3 + M4; M1 kiêm QA/Docs.
- Ghi lại thực tế ai làm gì (commit, PR) để điền bảng Contribution của đề.

---

## 9. Kế hoạch 5 tuần

| Tuần | Mục tiêu | Đầu ra kiểm chứng được |
|---|---|---|
| 1 | Nền móng | Auth JWT xong trong 1 ngày (5.1); `schema-snapshot.md` + phương án lưu đơn; hợp đồng API được cả nhóm duyệt; `mobile/` chạy được với theme, router, Login/Register gọi API thật; seed dữ liệu demo |
| 2 | Backend + Hotels | H1, H2, H3, A1 chạy trên deploy HTTPS; Search → List → Detail chạy với API thật |
| 3 | Đặt phòng | B1, B2, B3; Form → Review → Result → MyBookings chạy đầu-cuối; xử lý lỗi hết phòng, giá đổi, mất mạng; chống bấm đúp |
| 4 | P1 + chất lượng | Bản đồ 1 marker, Notifications, Chat (JSON); unit + widget test xanh; ảnh DevTools khi cuộn danh sách + bảng `--analyze-size`; sửa lỗi |
| 5 | Phát hành | APK/AAB release đã ký; video chạy release trên máy thật; ZIP source; PDF; slide; diễn tập 15 phút ×2 |

**Mốc dừng:** cuối tuần 3 mà luồng P0 chưa chạy đầu-cuối → dừng P1, dồn người vào P0.

---

## 10. Quy trình làm việc

- **Nhánh:** `main` luôn build được. Làm trên `feat/<mã-chức-năng>-<mô-tả>` (ví dụ `feat/F06-review-screen`), mở PR, cần ≥1 người duyệt.
- **Commit:** `feat(booking): ...`, `fix(hotels): ...`, `test: ...`, `docs: ...`.
- **Trước khi mở PR:** `flutter analyze` không lỗi, `flutter test` xanh, `dart format .`.
- **Comment (đề bắt buộc):** mỗi class public có doc comment `///`; mỗi chỗ cài quy tắc nghiệp vụ ghi mã BR (ví dụ `// BR-02: khoảng nửa mở [checkIn, checkOut)`); logic phức tạp (interceptor JWT, phân trang, khóa nút gửi) có giải thích *tại sao*.
- **Bí mật:** không commit `.env`, keystore, `key.properties`, service-role key, `MOBILE_JWT_SECRET`, `DEEPSEEK_API_KEY`. Phía Flutter **không chứa bí mật nào**, chỉ có `API_BASE_URL`. Kiểm tra ZIP trước khi nộp.
- **Definition of Done** cho một chức năng: chạy với API thật trên Android; có đủ state loading/empty/error; có comment; có ít nhất một test, hoặc ca thủ công đã ghi kết quả; được duyệt PR.

---

## 11. Kiểm thử, hiệu năng, phát hành

### 11.1. Test tự động

Mock repository bằng `mocktail` trong `test/mocks.dart`; không viết Fake repository trong `lib/`.

| ID | Loại | Nội dung | Người làm |
|---|---|---|---|
| UT-01 | Unit | `DateRules`: trả ≤ nhận → lỗi; nhận ở quá khứ → lỗi; 10/11–12/11 → 2 đêm; > 30 đêm → lỗi | M3 |
| UT-02 | Unit | `Validators`: email, SĐT VN, họ tên, mật khẩu | M2 |
| UT-03 | Unit | `BookingViewModel` với `MockBookingRepository`: thành công → `success`; repo ném `AppException(PRICE_CHANGED)` → `error` đúng mã; gọi `submit()` 2 lần liên tiếp → `verify(...).called(1)` | M4 |
| WT-01 | Widget | `SearchScreen`: ngày sai hiện lỗi và **không** gọi tìm kiếm; ngày đúng thì gọi `load()` | M3 |
| WT-02 | Widget | `HotelListScreen` với mock repo: hiển thị đúng skeleton / empty / error + nút Thử lại | M3 |

Mức tối thiểu theo đề là UT-01 + WT-01; các ca còn lại nên làm. Lệnh: `flutter test`. Lưu output vào `docs/mobile/test-results/`.

### 11.2. Ca thủ công / tích hợp

| ID | Tình huống | Kỳ vọng |
|---|---|---|
| TC-01 | Đăng ký email mới, đăng ký trùng email, đăng nhập đúng/sai, đăng xuất rồi mở My bookings | Trùng → `EMAIL_TAKEN`; sai → thông báo chung; sau đăng xuất bị chuyển về Login |
| TC-02 | Tìm có kết quả / không kết quả / tắt mạng | Hiển thị đúng 3 state, Thử lại hoạt động |
| TC-03 | Đặt hợp lệ; số khách vượt sức chứa; sửa giá trong DB rồi bấm Xác nhận; đặt phòng đã hết | Chỉ tạo đơn khi hợp lệ; giá đổi hoặc hết phòng → báo lỗi, quay lại chi tiết tải được giá mới, không tạo đơn |
| TC-04 | Gọi `GET /bookings/{id}` của user khác bằng token user B (Postman); gọi B1 không token | `404`; `401` |
| TC-05 | Bấm "Xác nhận đặt" liên tục nhiều lần; tắt mạng rồi bấm | Đúng **1** đơn trong DB (đối chiếu bằng SQL); mất mạng → báo lỗi, không hiện thành công |
| TC-06 | Cài APK release lên máy thật, chạy đủ luồng | Video + model máy + phiên bản Android + version app |

### 11.3. Hiệu năng

Áp dụng ngay khi code, không đợi đo rồi mới sửa:

- `ListView.builder` + phân trang 20 item.
- `cached_network_image` cho mọi ảnh mạng.
- `const` constructor ở mọi chỗ có thể (bật lint `prefer_const_constructors`).
- `context.select` / `Selector` cho widget chỉ cần một phần state.

Minh chứng đưa vào báo cáo:

1. Chạy `flutter run --profile` trên máy thật, mở **Flutter DevTools → Performance**, cuộn HotelList → **chụp ảnh biểu đồ frame time/FPS**.
2. `flutter build apk --release --analyze-size --target-platform android-arm64` → chụp/ghi **bảng dung lượng** theo package.
3. Ghi rõ máy, phiên bản Android, bản build.

Không ghi các con số "nhanh hơn X%" nếu không đo.

### 11.4. Build release

```bash
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://<deploy>.vercel.app
```

- Tạo keystore riêng của nhóm; `key.properties` nằm trong `.gitignore`.
- `applicationId` đề xuất `com.tripc.mobile`, tránh trùng `com.tripc.app` của bản Capacitor. `versionName 1.0.0`.
- Quyền Android: `INTERNET`.
- Bằng chứng release: video cài APK lên máy thật, mở app (không có banner DEBUG), chạy đủ luồng.

---

## 12. Báo cáo và demo

**Báo cáo PDF** theo đúng 7 mục của đề:
1. Team Introduction
2. Case Study (dùng mục 3)
3. Business Analysis / System Design (dùng mục 3, 4, 5, 6 + sơ đồ use case, ERD các bảng thật, sơ đồ kiến trúc, UI flow, công nghệ mới: JWT với `jose`, go_router, flutter_map, mocktail)
4. Development Requirements (UI, state, DB, test, release)
5. Demo (ảnh thật)
6. Conclusion & Discussion: lấy bảng vấn đề ở mục 2.3 làm bài học (không tin giá từ client, kiểm tra quyền sở hữu). Nêu thẳng hạn chế của chính bản mobile:
   - không có transaction khi trừ phòng (BR-07);
   - không có idempotency phía server (BR-08);
   - tài khoản mobile tách biệt với web;
   - đơn `pending` không tự hết hạn.

   Cả 4 điểm trên cũng là hướng cải tiến.
7. Contribution (bảng % theo đề, tổng mỗi dòng 100%)

**Kịch bản demo 15 phút:**
- 2' — case study + kiến trúc
- 7' — demo: đăng ký/đăng nhập → tìm → chi tiết + bản đồ → đặt → đơn của tôi → thông báo / chat
- 3' — luồng state (BookingViewModel), DB/API, chạy `flutter test` trực tiếp
- 2' — bằng chứng release + ảnh DevTools + bảng dung lượng
- 1' — kết luận

Chuẩn bị video dự phòng nếu mạng phòng thi yếu.

**Nộp:** ZIP toàn bộ `mobile/` (cộng các route và migration backend nhóm đã viết), PDF báo cáo lên EduNext. Ghi nguồn tham khảo đầy đủ (đề cảnh báo đạo văn).

---

## 13. Việc cần quyết định / còn thiếu

| # | Việc | Ai | Hạn |
|---|---|---|---|
| 1 | Hỏi giảng viên: có chấm theo 10 chức năng của Project Sample không? | Trưởng nhóm | Tuần 1 |
| 2 | Danh sách 3–5 thành viên và vai trò M1–M5 | Cả nhóm | Tuần 1 |
| 3 | Dùng Supabase/Vercel nào cho demo (gốc hay project riêng của nhóm), ai giữ `MOBILE_JWT_SECRET`, service-role key và DeepSeek key | M1 | Tuần 1 |
| 4 | Schema thật, dữ liệu seed, phương án lưu đơn (a) hay (b) ở mục 5.2 | M1 | Hết tuần 1 |
