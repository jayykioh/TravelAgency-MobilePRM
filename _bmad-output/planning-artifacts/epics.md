---
status: final
stepsCompleted: [step-01-validate-prerequisites, step-02-design-epics, step-03-create-stories, step-04-final-validation]
inputDocuments:
  - _bmad-output/specs/spec-flutter-mobile-migration/SPEC.md
  - _bmad-output/specs/spec-flutter-mobile-migration/business-rules.md
  - _bmad-output/specs/spec-flutter-mobile-migration/architecture-and-state.md
  - _bmad-output/specs/spec-flutter-mobile-migration/api-contract.md
  - _bmad-output/specs/spec-flutter-mobile-migration/ux-and-screens.md
  - _bmad-output/specs/spec-flutter-mobile-migration/delivery-and-quality.md
---

# TravelAgency-MobilePRM - Epic Breakdown

## Overview

Tài liệu phân rã yêu cầu migrate duy nhất module Hotel Booking từ React/Next.js sang Flutter trong 3 ngày cho 4 thành viên. Nội dung được trích xuất từ bộ spec đã chốt; không mở rộng backend hoặc các module ngoài Hotel.

## Requirements Inventory

### Functional Requirements

FR1: Ứng dụng phải khởi tạo Flutter, cấu hình Supabase bằng URL và publishable/anon key, đồng thời khôi phục session hợp lệ.

FR2: Người dùng có thể đăng ký, đăng nhập, đăng xuất bằng Supabase Auth khi compatibility gate với quyền truy cập hiện hữu đạt.

FR3: Người dùng có thể tìm khách sạn theo tên/địa chỉ/thành phố, ngày nhận phòng, ngày trả phòng và số khách/phòng.

FR4: Người dùng có thể lọc theo khoảng giá, hạng sao, tiện nghi và loại hình có trong dữ liệu; có thể xóa toàn bộ bộ lọc.

FR5: Người dùng có thể sắp xếp kết quả theo giá tăng/giảm, đánh giá và độ phổ biến theo dữ liệu hiện hữu.

FR6: Người dùng có thể xem chi tiết khách sạn gồm gallery, địa chỉ, mô tả, chính sách, tiện nghi, AI insight và reviews theo nguồn hiện hữu.

FR7: Người dùng có thể xem loại phòng, ảnh phòng, sức chứa, tiện nghi, chính sách và giá từng đêm.

FR8: Hệ thống phải tính giá theo hotel_rates trong khoảng ngày; nếu thiếu thì dùng rate gần nhất, sau đó fallback base_price/best_price của phòng.

FR9: Người dùng có thể chọn phòng, số lượng phòng và tiếp tục sang checkout mà không bị khóa chỉ vì ngày chọn thiếu hotel_rates.

FR10: Checkout phải validate họ tên, email, số điện thoại, ghi chú; giữ draft khi quay lại và hiển thị đầy đủ tóm tắt cùng price breakdown.

FR11: Người dùng có thể gửi yêu cầu đặt phòng, nhận booking ID thật và tạo hotel_bookings với status pending, payment_status pending.

FR12: Người dùng có thể xem lịch sử, lọc trạng thái, xem chi tiết đơn thuộc session hiện tại và hủy đơn pending thành cancelled.

FR13: Provider phải giữ search criteria, khách sạn/phòng đã chọn, quote và booking draft xuyên suốt luồng và auth guard.

FR14: Ứng dụng phải có loading, empty, error, retry và phản hồi UI cho mọi thao tác Search, Filter, chọn ngày, đặt phòng và hủy phòng.

FR15: Ứng dụng phải hoàn tất luồng P0 Login/Register → Search → Detail/Room → Guest Form → Review/Pending → History/Detail.

FR16: Nếu P0 hoàn tất đúng hạn, nhóm có thể thực hiện Map, Notifications hoặc Chat bằng nguồn hiện hữu; nếu P0 trễ thì cắt toàn bộ P1.

### NonFunctional Requirements

NFR1: Chỉ migrate module Hotel; loại Flights, Shop, Events, Dining, Transport, Partner và thanh toán online khỏi phạm vi.

NFR2: Không tạo hoặc sửa backend, database, migration, seed, RLS, auth server hay route /api/mobile/v1.

NFR3: Không đưa service-role hoặc server secret vào Flutter; chỉ dùng publishable/anon key và session người dùng.

NFR4: UI Flutter phải bám sát hierarchy, màu #FF5E1F, radius 32, pill input/button, typography, spacing và hình ảnh/fallback của React/Next.js.

NFR5: Screens không gọi Supabase trực tiếp; luồng phụ thuộc là Screens → Provider/ChangeNotifier → Services/Repositories → nguồn hiện hữu.

NFR6: Submit mutation phải chống double-tap, không tự retry mutation khi timeout và chỉ báo thành công khi nhận ID thật.

NFR7: flutter analyze phải đạt 0 issues và flutter test phải pass, gồm ít nhất unit test và widget test cho tương tác chính.

NFR8: P0 phải chạy đầu-cuối trước 18:00 Ngày 2; code freeze 12:00 Ngày 3; chiều Ngày 3 test chéo và đóng gói APK.

NFR9: Bốn thành viên đều làm code Flutter theo feature ownership; không có vai trò backend hoặc QA thuần túy.

NFR10: Không đưa slide, video, PDF, analyze-size hoặc công việc ngoài code vào lịch kỹ thuật 3 ngày.

### Additional Requirements

- Member 1 sở hữu bootstrap Flutter, models chung, clients/services, Provider, router, Auth và compatibility gate Auth/RLS/API.
- Member 2 sở hữu Home, Search Console, chọn ngày/khách/phòng, Filter, Sort và Listing.
- Member 3 sở hữu Hotel Detail, Gallery, Amenities, Reviews, Room Selection và rate fallback.
- Member 4 sở hữu Checkout, validation, price breakdown, create pending, My Bookings, detail và cancel pending.
- Models tối thiểu: UserSession, SearchCriteria, Hotel, HotelRoom, HotelRate/NightlyPrice, Quote, BookingDraft, HotelBooking và HotelReview.
- Handoff bắt buộc: criteria → selected hotel → selected room/quote → booking draft → booking ID.
- Ngày 1 hoàn tất base, contract models/services, Auth và UI tĩnh của toàn bộ P0.
- Ngày 2 nối dữ liệu thật, với gate 12:00 Search→Detail và gate 18:00 P0 đầu-cuối.
- Ngày 3 sáng sửa integration/loading/error, 12:00 freeze, chiều test chéo và build/cài APK.
- Blocker Auth/RLS/API phải được ghi đúng thực tế; không được biến blocker thành task sửa backend.

### UX Design Requirements

UX-DR1: Home/Listing phải có Hero, Search Console nổi, bộ lọc responsive và danh sách/lưới Hotel Cards bám sát bản React.

UX-DR2: Vùng chọn Check-in/Check-out phải mở DatePicker, cập nhật ngày ngay và đảm bảo check-out sau check-in tối thiểu một đêm.

UX-DR3: Bộ chọn khách/phòng phải có tương tác tăng/giảm Adults, Children, Rooms và cập nhật kết quả theo sức chứa.

UX-DR4: Search phải phản hồi bằng loading/đếm kết quả và đưa người dùng đến vùng kết quả.

UX-DR5: Detail phải có gallery xem ảnh, thông tin, amenities, AI insight/reviews, room cards và Reserve Bar cập nhật theo lựa chọn.

UX-DR6: Checkout phải hiển thị validation tại trường, tóm tắt đơn và price breakdown gồm giá × đêm × phòng, thuế 10%, phí dịch vụ 5% và tổng.

UX-DR7: My Bookings phải có filter trạng thái, booking detail, badge trạng thái và thao tác cancel chỉ khi pending.

UX-DR8: Image.network phải dùng đúng cột ảnh/fallback logic của web và luôn có errorBuilder để tránh khung trắng.

UX-DR9: Mọi màn hình phải có loading, empty, error và retry state rõ ràng; thao tác mutation phải thể hiện disabled/loading.

UX-DR10: Layout phải thích ứng mobile, Chrome demo, emulator và máy thật mà không có lớp Stack/Positioned chặn hit-test.

### FR Coverage Map

FR1: Epic 1 - Khởi tạo client, session và nguồn dữ liệu dùng chung.
FR2: Epic 1 - Đăng ký, đăng nhập và đăng xuất.
FR3: Epic 2 - Search theo từ khóa, ngày và số khách/phòng.
FR4: Epic 2 - Filter và clear filter.
FR5: Epic 2 - Sort kết quả.
FR6: Epic 3 - Nội dung chi tiết, gallery, insight và reviews.
FR7: Epic 3 - Danh sách và thông tin phòng.
FR8: Epic 3 - Rate theo ngày và chuỗi fallback.
FR9: Epic 3 - Chọn phòng và Reserve Bar.
FR10: Epic 4 - Form khách, draft và price breakdown.
FR11: Epic 4 - Tạo booking pending.
FR12: Epic 5 - Lịch sử, chi tiết và hủy booking.
FR13: Epic 1 - Giữ state qua auth guard và navigation.
FR14: Epic 2 - Loading, empty, error, retry và phản hồi thao tác.
FR15: Epic 5 - Hoàn tất luồng P0 đầu-cuối.
FR16: Epic 6 - Notifications và AI Chat dùng nguồn hiện hữu; HotelsMap được đưa vào Epic 2.

## Epic List

### Epic 1: Hồ sơ & Auth
Người dùng có thể đăng ký, đăng nhập, khôi phục phiên, xem/cập nhật hồ sơ và tiếp tục luồng Hotel không mất dữ liệu đã nhập.
**FRs covered:** FR1, FR2, FR13.

### Epic 2: Hotels Discovery & HotelsMap
Người dùng có thể tìm, lọc, sắp xếp khách sạn và chuyển giữa danh sách với bản đồ để chọn nơi lưu trú.
**FRs covered:** FR3, FR4, FR5, FR14; phần HotelsMap của FR16.

### Epic 3: Chi tiết khách sạn & Chọn phòng
Người dùng có thể đánh giá khách sạn, xem phòng và chọn phương án có giá hợp lệ cho ngày lưu trú.
**FRs covered:** FR6, FR7, FR8, FR9.

### Epic 4: Checkout & Tạo đơn
Người dùng có thể nhập thông tin khách, xem tổng giá và tạo yêu cầu đặt phòng pending bằng dữ liệu thật.
**FRs covered:** FR10, FR11.

### Epic 5: My Bookings
Người dùng có thể theo dõi, xem chi tiết và hủy đơn pending của chính mình.
**FRs covered:** FR12, FR15.

### Epic 6: Notifications & AI Chat
Người dùng có thể đọc thông báo và trao đổi với trợ lý AI trong ứng dụng qua nguồn hiện hữu.
**FRs covered:** phần Notifications và AI Chat của FR16.

## Epic 1: Hồ sơ & Auth

Người dùng truy cập an toàn vào ứng dụng và quản lý hồ sơ mà không làm mất ngữ cảnh Hotel đang thực hiện. **Owner chính: Member 1.**

### Story 1.1: Đăng ký và đăng nhập bằng Supabase Auth

As a người dùng,
I want đăng ký hoặc đăng nhập bằng email và mật khẩu,
So that tôi có session hợp lệ để sử dụng các chức năng Hotel.

**Acceptance Criteria:**

**Given** cấu hình Supabase hợp lệ
**When** người dùng gửi form đăng ký hoặc đăng nhập hợp lệ
**Then** ứng dụng nhận và lưu session thật, hiển thị trạng thái loading/error đúng
**And** không sử dụng service-role, backend mới hoặc mock session.

### Story 1.2: Khôi phục phiên và Auth Guard giữ ngữ cảnh

As a người dùng quay lại ứng dụng,
I want phiên đăng nhập và dữ liệu đặt phòng dở dang được khôi phục,
So that tôi không phải thực hiện lại từ đầu.

**Acceptance Criteria:**

**Given** người dùng có session hoặc booking draft trước đó
**When** ứng dụng khởi động hoặc điều hướng qua auth guard
**Then** session được khôi phục và criteria, selected room, quote, draft vẫn còn
**And** logout xóa session nhưng không làm ứng dụng crash.

### Story 1.3: Xem và cập nhật Hồ sơ

As a người dùng đã đăng nhập,
I want xem và sửa thông tin hồ sơ cơ bản,
So that dữ liệu liên hệ của tôi chính xác khi đặt phòng.

**Acceptance Criteria:**

**Given** session hợp lệ và nguồn profile hiện hữu
**When** người dùng mở tab Hồ sơ và lưu thay đổi hợp lệ
**Then** màn hình hiển thị avatar/name/email/phone và cập nhật qua contract hiện hữu
**And** nếu nguồn không cho ghi, UI báo lỗi rõ ràng thay vì tạo backend hoặc bảng mới.

## Epic 2: Hotels Discovery & HotelsMap

Người dùng tìm thấy khách sạn phù hợp trên danh sách hoặc bản đồ. **Owner chính: Member 2; Member 1 hỗ trợ data contract.**

### Story 2.1: Tìm kiếm theo từ khóa, ngày và số khách/phòng

As a khách du lịch,
I want nhập điểm đến, ngày và cơ cấu khách/phòng,
So that tôi nhận danh sách khách sạn có khả năng đáp ứng.

**Acceptance Criteria:**

**Given** Home đã tải dữ liệu thật
**When** người dùng chọn date range hợp lệ, Adults/Children/Rooms và bấm Search
**Then** Provider lọc theo tên/địa chỉ/thành phố và sức chứa, báo số kết quả và cuộn tới listing
**And** checkout luôn sau check-in ít nhất một đêm.

### Story 2.2: Lọc, sắp xếp và xóa bộ lọc

As a khách du lịch,
I want lọc và sắp xếp kết quả,
So that tôi nhanh chóng tìm lựa chọn phù hợp ngân sách và sở thích.

**Acceptance Criteria:**

**Given** danh sách khách sạn đã tải
**When** người dùng đổi price range, stars, amenities, accommodation type hoặc sort
**Then** kết quả cập nhật tức thì theo tổ hợp điều kiện
**And** Clear Filters khôi phục trạng thái mặc định mà vẫn giữ ngày và số khách.

### Story 2.3: Xem và chọn khách sạn trên HotelsMap

As a khách du lịch,
I want xem khách sạn trên bản đồ và chọn marker,
So that tôi có thể quyết định dựa trên vị trí.

**Acceptance Criteria:**

**Given** khách sạn có latitude/longitude hợp lệ
**When** người dùng mở HotelsMap hoặc chạm marker
**Then** map hiển thị marker và card tóm tắt đồng bộ với filter hiện tại
**And** khách sạn thiếu tọa độ không làm hỏng bản đồ và vẫn tồn tại ở list.

### Story 2.4: Trạng thái tải, rỗng, lỗi và retry

As a người dùng,
I want thấy phản hồi rõ ràng khi tải dữ liệu,
So that tôi hiểu ứng dụng đang xử lý hay cần thử lại.

**Acceptance Criteria:**

**Given** request đang tải, trả rỗng hoặc lỗi
**When** trạng thái thay đổi
**Then** UI hiển thị loading/empty/error/retry tương ứng và không chặn hit-test Search Console
**And** retry không tự lặp mutation hoặc gây submit kép.

## Epic 3: Chi tiết khách sạn & Chọn phòng

Người dùng có đủ thông tin và mức giá hợp lệ để chọn phòng. **Owner chính: Member 3.**

### Story 3.1: Xem gallery và nội dung chi tiết khách sạn

As a khách du lịch,
I want xem ảnh, địa chỉ, mô tả, chính sách và tiện nghi,
So that tôi hiểu rõ nơi lưu trú trước khi chọn phòng.

**Acceptance Criteria:**

**Given** người dùng chọn một hotel thật
**When** Detail mở
**Then** gallery, location, description, policies và amenities dùng dữ liệu/cột ảnh như web
**And** ảnh lỗi dùng fallback và không để khung trắng.

### Story 3.2: Xem AI Insight và Reviews

As a khách du lịch,
I want xem điểm, nhận xét và phần tóm tắt,
So that tôi đánh giá chất lượng khách sạn.

**Acceptance Criteria:**

**Given** nguồn reviews hoặc aggregate hiện hữu
**When** Detail tải thành công
**Then** UI hiển thị rating, count, insight và review list theo dữ liệu có thật
**And** nếu bảng reviews không tồn tại thì dùng aggregate hiện hữu, không bịa review.

### Story 3.3: Xem phòng và giá fallback

As a khách du lịch,
I want xem thông tin phòng cùng giá mỗi đêm,
So that tôi luôn có thể lựa chọn dù ngày hiện tại thiếu rate.

**Acceptance Criteria:**

**Given** hotel_rooms và hotel_rates hiện hữu
**When** khoảng ngày không có đủ rate
**Then** giá ưu tiên rate theo ngày, rồi rate gần nhất, rồi base_price/best_price
**And** không hiển thị lỗi khóa đặt phòng chỉ vì thiếu hotel_rates.

### Story 3.4: Chọn phòng và cập nhật Reserve Bar

As a khách du lịch,
I want đổi ngày/số phòng và chọn loại phòng,
So that tôi thấy quote mới trước khi checkout.

**Acceptance Criteria:**

**Given** phòng đủ capacity
**When** người dùng chọn phòng hoặc thay đổi ngày/số lượng phòng
**Then** Reserve Bar cập nhật số đêm, giá và tổng ngay lập tức
**And** Continue chuyển đúng selected room và quote sang checkout.

## Epic 4: Checkout & Tạo đơn

Người dùng hoàn thành yêu cầu đặt phòng pending. **Owner chính: Member 4; Member 1 hỗ trợ Auth/RLS.**

### Story 4.1: Nhập và giữ thông tin khách

As a người đặt phòng,
I want nhập thông tin liên hệ và yêu cầu đặc biệt,
So that khách sạn có dữ liệu xử lý yêu cầu.

**Acceptance Criteria:**

**Given** selected room và quote tồn tại
**When** người dùng nhập họ tên, email, điện thoại và ghi chú
**Then** form validate đúng và giữ draft khi Back
**And** lỗi được hiển thị tại trường tương ứng.

### Story 4.2: Xem tóm tắt và bảng giá

As a người đặt phòng,
I want xem lại toàn bộ chi tiết và tổng giá,
So that tôi xác nhận trước khi gửi yêu cầu.

**Acceptance Criteria:**

**Given** draft hợp lệ
**When** Checkout hiển thị
**Then** có hotel, room, ngày, đêm, khách, số phòng và giá × đêm × phòng
**And** thuế 10%, phí dịch vụ 5% và tổng được tính nhất quán, voucher chỉ xuất hiện nếu nguồn web hỗ trợ.

### Story 4.3: Tạo booking pending an toàn

As a người đặt phòng,
I want gửi yêu cầu đặt phòng,
So that tôi nhận mã đơn và có thể theo dõi trạng thái.

**Acceptance Criteria:**

**Given** form hợp lệ và session/quyền ghi hợp lệ
**When** người dùng bấm xác nhận một lần
**Then** hotel_bookings được tạo với status pending, payment_status pending và trả ID thật
**And** nút bị khóa khi submit; lỗi RLS/API được báo đúng, không tạo backend mới.

## Epic 5: My Bookings

Người dùng quản lý các đơn đặt phòng của chính mình. **Owner chính: Member 4; Member 1 hỗ trợ session ownership.**

### Story 5.1: Xem và lọc danh sách đơn

As a người dùng đã đăng nhập,
I want xem các đơn của mình theo trạng thái,
So that tôi nhanh chóng biết tình trạng đặt phòng.

**Acceptance Criteria:**

**Given** session hợp lệ
**When** người dùng mở My Bookings hoặc chọn All/Pending/Confirmed/Cancelled
**Then** danh sách chỉ chứa đơn thuộc user hiện tại và hiển thị badge đúng
**And** loading/empty/error state rõ ràng.

### Story 5.2: Xem chi tiết đơn

As a người dùng,
I want xem mã đơn, thời gian ở, giá và thông tin khách,
So that tôi có đầy đủ bằng chứng về yêu cầu đặt phòng.

**Acceptance Criteria:**

**Given** người dùng chọn một booking thuộc quyền sở hữu
**When** màn hình chi tiết mở
**Then** hotel, room, booking code, dates, guests, total và status được hiển thị
**And** không cho truy cập đơn của user khác.

### Story 5.3: Hủy đơn pending

As a người dùng,
I want hủy yêu cầu chưa được xác nhận,
So that trạng thái đơn phản ánh quyết định mới nhất.

**Acceptance Criteria:**

**Given** booking có status pending
**When** người dùng xác nhận Cancel Booking
**Then** Supabase cập nhật status cancelled và UI phản ánh ngay
**And** đơn không phải pending không hiển thị hành động hủy.

### Story 5.4: Nghiệm thu P0 và đóng gói

As a nhóm phát triển,
I want kiểm tra luồng Hotel đầu-cuối,
So that bản demo PRM393 ổn định trên Chrome và thiết bị.

**Acceptance Criteria:**

**Given** các story P0 hoàn tất
**When** chạy analyze, unit/widget tests và demo end-to-end
**Then** analyze đạt 0 issues, test pass và luồng Search→Detail→Checkout→My Bookings→Cancel hoạt động
**And** APK build/cài/chạy được trước khi bàn giao.

## Epic 6: Notifications & AI Chat

Người dùng nhận thông tin và hỗ trợ trong ứng dụng; đây là màn hình bắt buộc của bài PRM393, không được để trống. **Owner: Member 1 (Notifications service), Member 3 (AI Chat UI/service).**

### Story 6.1: Xem và đánh dấu thông báo

As a người dùng,
I want xem danh sách thông báo và trạng thái đã đọc,
So that tôi không bỏ lỡ cập nhật đặt phòng.

**Acceptance Criteria:**

**Given** session và nguồn notifications hiện hữu
**When** người dùng mở tab Notifications hoặc chọn một thông báo
**Then** UI hiển thị title, content, time, read state và cập nhật read qua contract hiện hữu
**And** nếu API không tương thích session, UI báo blocker thật thay vì dữ liệu mock hoặc backend mới.

### Story 6.2: Bắt đầu và tiếp tục hội thoại AI Chat

As a khách du lịch,
I want gửi tin nhắn cho trợ lý AI,
So that tôi nhận hỗ trợ liên quan đến khách sạn và chuyến đi.

**Acceptance Criteria:**

**Given** API chat hiện hữu có thể được gọi an toàn từ Flutter
**When** người dùng gửi nội dung không rỗng
**Then** UI hiển thị user/assistant messages, loading, retry và lịch sử conversation
**And** không nhúng server secret hoặc tạo API mới.

### Story 6.3: Gắn Notifications và AI Chat vào điều hướng chính

As a người dùng,
I want truy cập nhanh các feature từ navigation,
So that mọi màn hình chấm điểm đều có thể demo bằng thao tác thật.

**Acceptance Criteria:**

**Given** ứng dụng khởi động
**When** người dùng dùng thanh điều hướng chính
**Then** có lối vào Hotels, Map, My Bookings, Notifications, AI Chat và Profile/Auth
**And** tab giữ state hợp lý, có loading/empty/error state, không để placeholder trắng.

