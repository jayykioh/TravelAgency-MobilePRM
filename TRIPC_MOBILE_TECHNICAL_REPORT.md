# TECHNICAL REPORT: MOBILE TRAVEL BOOKING APPLICATION

**Course:** Flutter Application Development  
**Team Size:** 4 Members  
**Project Name:** TripC Hotels (TravelAgency-MobilePRM)

________________________________________

## 1. Team Introduction

| Full Name | Role | Responsibilities | Contribution |
|---|---|---|---:|
| Đoàn Trọng Lực | Team Member | Phân tích nghiệp vụ, phát triển và kiểm thử ứng dụng theo phân công của nhóm | 25% |
| Võ Hà Đông | Team Member | Phân tích nghiệp vụ, phát triển và kiểm thử ứng dụng theo phân công của nhóm | 25% |
| Nguyễn Vũ Hoàng | Team Member | Phân tích nghiệp vụ, phát triển và kiểm thử ứng dụng theo phân công của nhóm | 25% |
| Phạm Tuấn Huy | Team Member | Phân tích nghiệp vụ, phát triển và kiểm thử ứng dụng theo phân công của nhóm | 25% |

*Ghi chú:* Repository không ghi nhận trách nhiệm cá nhân cho từng hạng mục. Bảng trên thể hiện mức đóng góp 25% mỗi thành viên theo thông tin nhóm cung cấp; cần thay mô tả công việc nếu nhóm có phân công thực tế chi tiết hơn.

________________________________________

## 2. Case Study

**Project Title:** TripC Hotels – Ứng dụng di động tìm kiếm và gửi yêu cầu đặt phòng khách sạn.  
**Domain:** Travel Booking / Hotel Reservation.  
**Description:**  
TripC Hotels là ứng dụng Flutter triển khai trải nghiệm đặt phòng khách sạn trên thiết bị di động, tham chiếu luồng của nền tảng TripC trên web. Người dùng có thể tìm khách sạn theo địa điểm, ngày ở, số khách và bộ lọc; xem thông tin khách sạn, phòng, giá và bản đồ; nhập thông tin liên hệ và gửi **yêu cầu đặt phòng ở trạng thái chờ xác nhận, chưa thanh toán**. Ứng dụng còn có trang lịch sử đặt phòng, hồ sơ, thông báo, AI chat và màn hình Tcent/voucher. Dữ liệu khách sạn và đơn đặt phòng được truy cập qua Supabase; một số chức năng gọi API Next.js hiện hữu. Giao diện và luồng có mã nguồn, nhưng tính tương thích của phiên đăng nhập Flutter với backend đang dùng Clerk và RLS chưa được xác nhận đầy đủ trên môi trường thật.

________________________________________

## 3. Business Analysis / System Design

### 3.1. Requirements

- **Functional Requirements:** Đăng ký/đăng nhập; xem và cập nhật hồ sơ; tìm kiếm/lọc khách sạn; xem ảnh, tiện nghi, đánh giá, phòng và giá theo ngày; chọn phòng và nhập thông tin khách; gửi yêu cầu đặt phòng; xem/hủy đơn đang chờ khi backend cho phép; xem khách sạn trên bản đồ; xem/đánh dấu thông báo đã đọc; chat với trợ lý AI qua API hiện hữu; xem Tcent, vòng quay và voucher.
- **Non-functional Requirements:**
  - **Bảo mật:** Chỉ dùng Supabase URL và public/anon key trong app; các thao tác theo người dùng phải qua phiên đăng nhập và quyền backend/RLS. Không đưa service-role key, khóa AI hoặc bí mật server vào Flutter.
  - **Tính đúng đắn:** Giá phòng tính theo số đêm, số phòng và nguồn rate; hiển thị “giá tham khảo” khi không có rate phủ toàn bộ kỳ nghỉ. Chỉ báo tạo đơn thành công khi backend trả về ID thật.
  - **Khả dụng:** Có trạng thái tải dữ liệu, không có dữ liệu và lỗi; biểu mẫu kiểm tra tên, email, số điện thoại; giữ ngữ cảnh tìm kiếm và thông tin khách qua các bước điều hướng.
  - **Phụ thuộc kết nối:** Tìm khách sạn, tài khoản, đơn, thông báo và chat cần dịch vụ backend; repository không chứng minh chế độ offline đầy đủ hoặc chỉ tiêu thời gian tải cố định.

### 3.2. Application Architecture

Ứng dụng dùng Flutter với kiến trúc phân lớp và Provider/ChangeNotifier:

1. **UI Layer:** `mobile/lib/screens/` và `mobile/lib/widgets/` chứa màn hình, biểu mẫu, thẻ khách sạn, bản đồ, checkout và điều hướng.
2. **State / Business Logic Layer:** `mobile/lib/providers/hotel_state.dart` giữ trạng thái tìm kiếm, khách sạn/phòng đã chọn và dữ liệu của luồng đặt phòng; các model như `RoomQuote` và `BookingRequest` thực hiện quy tắc giá, kiểm tra dữ liệu và tạo payload.
3. **Data Layer:** `HotelService` đọc/ghi các bảng Supabase và gọi API Next.js hiện hữu; `VoucherService` xử lý dữ liệu Tcent/voucher và có dữ liệu dự phòng để trình diễn khi truy cập backend thất bại.

**Luồng chính:** Người dùng → Flutter Screen → `HotelState` / model → `HotelService` → Supabase hoặc API Next.js hiện hữu → phản hồi về giao diện. App Flutter không chứa logic xác nhận thanh toán hay giữ chỗ phía server.

### 3.3. Database Design (Supabase / PostgreSQL)

Ứng dụng Flutter **không dùng SQLite** trong phạm vi hiện tại. Các bảng dưới đây là cấu trúc dữ liệu mà mã Flutter đang truy cập; đây không phải bản xác nhận schema hoặc quyền RLS của database đang chạy.

| Table | Các trường/quan hệ được app sử dụng | Mục đích |
|---|---|---|
| `hotels` | `id`, `name`, `address`, `images`, `star_rating`, `amenities`, `best_price` | Danh sách, bộ lọc, chi tiết và tọa độ bản đồ. |
| `hotel_rooms` | `id`, `hotel_id`, `title`, `capacity`, `status` | Danh sách phòng đang hoạt động và sức chứa. |
| `hotel_rates` | `room_id`, `partner_id`, `date`, `price_cents`, `available_rooms`, `currency`, chính sách giá | Tính báo giá cho kỳ nghỉ; kiểm tra rate và phòng theo từng đêm. |
| `hotel_bookings` | `id`, `user_uuid`, `hotel_id`, `room_id`, `check_in_date`, `check_out_date`, thông tin khách, `total_cents`, `status`, `payment_status`, `metadata` | Lưu yêu cầu đặt phòng `pending` / `pending`, tra cứu và hủy khi được phép. |
| `users` | `id`, `email`, `name`, `phone_number`, các trường hồ sơ | Đọc/cập nhật hồ sơ và liên kết chủ sở hữu đơn. |
| `notifications` | `id`, `user_id`, `is_read`, `created_at` | Danh sách thông báo của tài khoản và đánh dấu đã đọc. |
| `reviews` | `entity_id`, `rating`, `title`, `comment`, `status` | Hiển thị đánh giá khách sạn đã xuất bản. |
| `vouchers`, `user_vouchers`, `spin_history` | Mã voucher, điểm Tcent, lịch sử quay | Dữ liệu thưởng/voucher; một số nhánh có dữ liệu dự phòng trong bộ nhớ. |

**Quy tắc đặt phòng:** Tiền phòng là tổng giá các đêm cho số phòng đã chọn; mã tính thuế 10% và phí dịch vụ 5% trên tiền phòng, có xử lý chiết khấu voucher ở phía client. Đơn gửi lên backend là yêu cầu chờ xác nhận, không phải giao dịch thanh toán hay xác nhận còn phòng cuối cùng.

### 3.4. New Technologies (Ngoài chương trình học)

- **Supabase Flutter:** SDK cho xác thực và truy cập dữ liệu PostgreSQL từ ứng dụng Flutter bằng khóa public và quyền người dùng.
- **OpenStreetMap + `flutter_map`:** Hiển thị vị trí khách sạn từ tọa độ trong dữ liệu `hotels`.
- **Next.js API integration:** Flutter gọi các route hiện hữu như `/api/chat/messages` và `/api/hotels/insights` khi cấu hình `APP_API_BASE_URL`; tính tương thích xác thực và khóa dịch vụ phụ thuộc backend.
- **Provider / ChangeNotifier:** Quản lý trạng thái dùng chung giữa các màn hình và các bước đặt phòng.

________________________________________

## 4. Development Requirements

### 4.1. Implementation Details

- **Platform / Language:** Flutter, Dart 3.10; ứng dụng có cấu trúc build cho Android và các nền tảng Flutter được scaffold, nhưng báo cáo này tập trung luồng mobile Android.
- **State Management:** `ChangeNotifierProvider` tạo `HotelState` ở `main.dart`; `IndexedStack` giữ các tab Hotels, Map, Bookings, Alerts và Profile.
- **Authentication:** Màn hình Flutter gọi Supabase Auth; backend web hiện dùng Clerk. Mapping giữa `auth.uid()` của Supabase và `users.id`/`clerk_id`, cùng quyền RLS thật, là điều kiện cần kiểm chứng trước khi tuyên bố luồng hồ sơ và đặt phòng hoàn tất.
- **Hotel Discovery:** `HotelService` đọc tối đa 50 bản ghi từ `hotels`, lọc phía client theo thành phố, hạng sao, tiện nghi, loại chỗ ở và khoảng giá; kiểm tra phòng/rate theo ngày và sức chứa. Giới hạn 50 bản ghi và lọc phía client là giới hạn mở rộng dữ liệu hiện tại.
- **Room Quote / Checkout:** Chọn rate đủ từng đêm của cùng đối tác khi có; nếu thiếu thì dùng rate gần nhất hoặc `best_price` làm giá tham khảo. Form khách kiểm tra đầu vào; payload chứa ID người dùng, khách sạn, phòng, ngày ở, tiền, trạng thái `pending` và metadata nguồn giá.
- **Other Features:** Bản đồ dùng `flutter_map`; thông báo đọc từ `notifications`; AI chat gửi hội thoại tới API Next.js; màn hình voucher có nhánh dữ liệu giả lập/dự phòng nên không thể mặc nhiên xem là giao dịch điểm thật.
- **Configuration:** `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `APP_API_BASE_URL` được truyền qua `--dart-define` hoặc file cấu hình client-safe theo `mobile/README-HOTELS.md`.

### 4.2. Testing

- **Unit / Model Tests:** Repository có test cho model khách sạn, báo giá phòng, payload đặt phòng, voucher và các quy tắc dữ liệu liên quan.
- **Widget Tests:** Repository có test cho auth/profile, tương tác trang khách sạn, luồng detail → checkout và các widget khác.
- **Live Integration Tests:** Có thư mục `mobile/test_live/`; kết quả chạy với backend thật và quyền của tài khoản thật chưa được xác nhận trong lần lập report này.
- **Acceptance cần ghi lại khi nộp:** `flutter analyze`, `flutter test`, đăng nhập thực, đọc/sửa hồ sơ, tìm khách sạn, tạo đơn `pending` có ID thật, xem/hủy đơn, thông báo, chat và xử lý lỗi RLS/network. Sự tồn tại của test không đồng nghĩa các bước acceptance này đã pass.

### 4.3. Deployment

- **Build Mode:** Mục tiêu là Android release APK sau khi hoàn thành chức năng và acceptance; lệnh dự kiến `flutter build apk --release` với cấu hình public phù hợp.
- **Current Evidence:** Chưa có bằng chứng trong tài liệu đã xem về APK release đã ký, cài trên thiết bị/emulator và chạy xuyên suốt luồng với backend thật. Không ghi “đã triển khai thành công” khi chưa có kết quả này.
- **Proof cần đính kèm khi nộp:** Log `flutter analyze`/`flutter test`, ảnh màn hình các luồng chính, log build release, đường dẫn APK, phiên bản/build number và ảnh hoặc video chạy APK trên Android.

________________________________________

## 5. Demo of Functions

1. **Database/API Structure:** Giới thiệu các bảng `hotels`, `hotel_rooms`, `hotel_rates`, `hotel_bookings`, `users`, `notifications`; giải thích Supabase và hai API Next.js được Flutter gọi.
2. **Login / Profile Screen:** Đăng ký/đăng nhập Supabase Auth, xem và sửa trường hồ sơ được hỗ trợ; trình bày kết quả thực tế khi kiểm tra tương thích Clerk/RLS.
3. **Hotel List:** Tìm kiếm khách sạn, chọn ngày, số khách và áp dụng bộ lọc giá, sao, tiện nghi, loại khách sạn.
4. **Hotel Detail:** Xem ảnh, mô tả, đánh giá, phòng, điều kiện giá, số đêm và giá chính xác/giá tham khảo.
5. **Map Screen:** Xem marker khách sạn có tọa độ trên OpenStreetMap và chuyển sang chi tiết khách sạn.
6. **Checkout Screen:** Chọn phòng, nhập họ tên/email/số điện thoại, xem tiền phòng, thuế, phí và voucher nếu có.
7. **Booking Result / History:** Gửi yêu cầu `pending`, chỉ hiển thị thành công khi nhận ID từ backend; xem danh sách đơn và hủy đơn đủ điều kiện nếu phiên có quyền.
8. **Notifications:** Xem thông báo của người dùng và đánh dấu đã đọc qua bảng `notifications`.
9. **AI Chat:** Gửi câu hỏi tới `/api/chat/messages` và hiển thị phản hồi hoặc lỗi xác thực/kết nối.
10. **Tcent Rewards / Vouchers:** Minh họa số dư, vòng quay, marketplace và ví voucher; phân biệt dữ liệu backend với dữ liệu dự phòng trong bộ nhớ.
11. **State Management:** Minh họa `HotelState` giữ ngữ cảnh tìm kiếm, phòng đã chọn và dữ liệu đặt phòng khi chuyển màn hình.

________________________________________

## 6. Conclusion and Discussion

- **Pros:** Luồng mobile có mã nguồn cho các bước chính của đặt phòng khách sạn; kiến trúc tách màn hình, state, model và service; mô hình giá theo đêm và thông báo lỗi đặt phòng tương đối rõ; không nhúng khóa bí mật server trong app.
- **Cons:** Tương thích Supabase Auth với định danh Clerk và RLS của backend hiện hữu chưa được chứng minh; `users.clerk_id` trong schema là trường bắt buộc nên tạo hồ sơ từ Flutter có thể thất bại. Tạo/hủy đơn, thông báo và AI chat còn phụ thuộc quyền/session thật. Tìm khách sạn hiện giới hạn 50 bản ghi và lọc phía client. Chưa có bằng chứng release APK hoặc thanh toán online; voucher có nhánh demo/fallback.
- **Learning:** Nhóm có thể trình bày cách dùng Flutter và Provider để quản lý nhiều màn hình, cách truy cập dữ liệu Supabase với quyền người dùng, cách tính giá lưu bằng đơn vị cent, kiểm tra biểu mẫu và xử lý lỗi tích hợp giữa mobile với backend có sẵn.
- **Future Improvements:** Chốt phương án định danh và RLS được backend hỗ trợ; kiểm chứng tất cả luồng với tài khoản thật; chuyển tìm kiếm/lọc/phân trang phù hợp cho dữ liệu lớn; hoàn thiện xác thực voucher và xác nhận giá/tồn phòng phía server; chạy acceptance rồi build, cài và kiểm tra APK release. Thanh toán online chỉ nên bổ sung khi có phạm vi và backend hỗ trợ.

________________________________________

## 7. Contribution Table

| Topic | Effort | Đoàn Trọng Lực | Võ Hà Đông | Nguyễn Vũ Hoàng | Phạm Tuấn Huy |
|---|---:|---:|---:|---:|---:|
| Case Study Analysis | 100% | 25% | 25% | 25% | 25% |
| Business Analysis | 100% | 25% | 25% | 25% | 25% |
| System Design | 100% | 25% | 25% | 25% | 25% |
| Implementation | 100% | 25% | 25% | 25% | 25% |
| Testing | 100% | 25% | 25% | 25% | 25% |
| Documentation | 100% | 25% | 25% | 25% | 25% |
| **Overall Contribution** | **100%** | **25%** | **25%** | **25%** | **25%** |

*Bảng phân bổ theo tỷ lệ nhóm cung cấp; không suy diễn lịch sử commit thành mức đóng góp cá nhân.*

________________________________________

## 8. References

1. Flutter Documentation: https://docs.flutter.dev/
2. Provider Package: https://pub.dev/packages/provider
3. Supabase Flutter Documentation: https://supabase.com/docs/reference/dart/introduction
4. flutter_map Documentation: https://docs.fleaflet.dev/
5. Project sources: `mobile/README.md`, `mobile/README-HOTELS.md`, `mobile/pubspec.yaml`, `mobile/lib/`.
6. Project specification: `_bmad-output/specs/spec-flutter-mobile-migration/SPEC.md` và các tài liệu companion trong cùng thư mục.

