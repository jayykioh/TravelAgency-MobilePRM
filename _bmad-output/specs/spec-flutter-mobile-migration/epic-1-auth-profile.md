# Epic 1 — Xác thực, hồ sơ và giữ ngữ cảnh

## Mục tiêu

Cho phép người dùng đăng nhập/đăng ký bằng cơ chế hiện có, khôi phục phiên, xem/cập nhật hồ sơ của chính mình và tiếp tục luồng khách sạn mà không mất ngữ cảnh. Epic chỉ được coi là hoàn tất khi danh tính Flutter được backend hiện hữu chấp nhận và các quyền đọc/ghi tương ứng đã được chứng minh.

## Phạm vi

- Đăng nhập, đăng ký, đăng xuất và khôi phục phiên Supabase Auth nếu đó là đường truy cập đã được project hỗ trợ.
- Trạng thái phiên có thể quan sát được trong app và trạng thái UI tương ứng khi phiên đổi/hết hạn.
- Xem và cập nhật các trường hồ sơ được hỗ trợ: tên, giới thiệu, thành phố, số điện thoại.
- Giữ tiêu chí tìm kiếm, khách sạn/phòng đã chọn và bản nháp checkout qua đăng nhập, quay lại và điều hướng.
- Chặn thao tác cần danh tính/quyền khi chưa có phiên hợp lệ; không dùng guest ID làm bằng chứng đăng nhập hoặc quyền sở hữu.

Không bao gồm tạo auth provider mới, đồng bộ Clerk–Supabase, sửa backend/API/database/RLS, đổi email/tài khoản, hoặc hoàn thiện các phần Saved/Rewards/Settings đang hiển thị nhưng chưa nối nghiệp vụ.

## Cổng tương thích bắt buộc — trước khi tuyên bố Auth hoàn tất

Ghi lại bằng chứng trên đúng môi trường demo cho từng mục:

1. Xác định auth provider và session hiện được các route web/table/policies chấp nhận. Web hiện dùng Clerk; việc Supabase Auth được backend hiện tại chấp nhận chưa được chứng minh.
2. Xác định cách `auth.currentUser.id` liên hệ với user identity trong bảng `users` và các bảng cần dùng. Không giả định UUID Supabase bằng `users.id` hoặc Clerk ID.
3. Xác minh đọc/cập nhật hồ sơ và các thao tác cần đăng nhập được phép bằng session người dùng hiện tại qua RLS/API hiện hữu.
4. Xác minh đăng ký mới có thể hoàn tất xác minh email và dùng các thao tác cần thiết mà không cần tạo bảng, mapping, endpoint, policy hoặc service-role path mới.

Schema snapshot được kiểm tra trong repo khai báo `users.clerk_id` là `NOT NULL`, còn code Flutter có nhánh tạo `users` mà không gửi `clerk_id`. Đây là cảnh báo cần đối chiếu với schema/policies đang chạy, không phải bằng chứng thay thế cho kiểm tra production. Nếu cổng tương thích không đạt, giữ Auth/feature phụ thuộc ở trạng thái **Blocked**, ghi lỗi cụ thể và không tạo workaround phía backend/client.

## Story 1-1 — Đăng ký, đăng nhập và đăng xuất

### Yêu cầu

- Có thể chuyển giữa form đăng nhập và đăng ký.
- Email và mật khẩu được kiểm tra ở client trước khi gửi; mật khẩu không được lưu/log hoặc hiển thị lại.
- Nút submit có trạng thái chờ và không gửi lặp khi request đang chạy.
- Đăng ký có thể yêu cầu xác minh email; giao diện phân biệt “đã gửi xác minh” với “đã có session”.
- Lỗi credentials, xác minh email, mạng, rate limit và lỗi quyền được diễn đạt an toàn, có thể xử lý; không hiển thị nguyên văn exception/backend payload cho người dùng.
- Đăng xuất chỉ xuất hiện khi có session. Sau đăng xuất, UI không tiếp tục hiển thị hồ sơ hoặc dữ liệu thuộc phiên cũ.

### Tiêu chí chấp nhận

- Đăng nhập thành công chỉ khi SDK trả session/user hợp lệ; UI phản ánh chính user đó.
- Tài khoản chưa xác minh được hướng dẫn xác minh và không được xem như đã đăng nhập nếu provider chưa cấp session.
- Email/mật khẩu sai và lỗi mạng không làm mất tiêu chí tìm kiếm hoặc bản nháp checkout.
- Đăng xuất kết thúc phiên hiện hành; mở lại app không khôi phục phiên đã đăng xuất.
- Thử đăng nhập/đăng ký khi offline hoặc bị từ chối cho thông báo có thể hiểu, không tạo trạng thái success giả.
- Cổng tương thích ở trên phải đạt trước khi story này được chuyển `done`; nếu không, giữ `in-progress/blocked` cùng bằng chứng.

## Story 1-2 — Khôi phục phiên, auth guard và giữ ngữ cảnh

### Yêu cầu

- Khi khởi động, hiển thị trạng thái khởi tạo phiên trước khi quyết định UI signed-in/signed-out.
- Theo dõi thay đổi phiên đăng nhập/đăng xuất/hết hạn qua cơ chế auth SDK hiện hữu; các màn cần user cập nhật theo cùng một trạng thái nguồn.
- Khách sạn, tìm kiếm và bản đồ vẫn dùng được nếu không cần đăng nhập. Các thao tác người dùng như chỉnh sửa hồ sơ, booking cá nhân, hủy booking, notifications và API chat bị giới hạn theo yêu cầu auth/quyền của nguồn hiện hữu.
- Nếu một thao tác cần đăng nhập, giữ lại trạng thái hợp lệ, yêu cầu đăng nhập, rồi quay lại đúng bước sau khi đăng nhập thành công.
- Khi phiên hết hạn hoặc bị từ chối, xóa dữ liệu user khỏi UI và yêu cầu xác thực lại trước thao tác tiếp theo.
- Không dùng `guestOwnerRef` hoặc một ID tự sinh để thay thế danh tính đã xác thực cho booking, profile, notifications hoặc quyền sở hữu.

### Tiêu chí chấp nhận

- Refresh/khởi động lại khôi phục phiên chỉ khi auth SDK xác nhận session còn hợp lệ.
- Đăng nhập và đăng xuất cập nhật navigation/profile/data state mà không cần khởi động lại app.
- Quay lại từ màn Auth giữ nguyên search criteria, selected hotel/room và guest draft.
- Session thiếu/hết hạn hoặc API trả unauthorized không mở khóa thao tác user-scoped.
- Guest identifier, nếu còn cần cho một luồng guest được backend hỗ trợ, được tách rõ khỏi user identity và không được dùng để vượt RLS.

## Story 1-3 — Xem và cập nhật hồ sơ

### Yêu cầu

- Hồ sơ đọc từ đúng user identity theo hợp đồng auth đã xác minh; email hiển thị theo auth provider và mặc định chỉ đọc.
- Cho phép xem/cập nhật tên, giới thiệu, thành phố và số điện thoại nếu các field này tồn tại và được phép trong schema/API hiện hữu.
- Có loading, empty/missing profile, error, retry và save-in-progress state.
- Giữ lại dữ liệu đang nhập nếu save thất bại; chỉ cập nhật UI thành công sau phản hồi xác nhận từ nguồn hiện hữu.
- Không tạo profile row tự động nếu schema/permissions yêu cầu field hoặc quy trình mapping chưa được chứng minh.
- Chỉ hiển thị và cập nhật hồ sơ của session hiện tại; không fallback sang tìm user theo email nếu email không phải quan hệ identity được backend bảo đảm.

### Tiêu chí chấp nhận

- User A đọc và cập nhật được hồ sơ A; không đọc/cập nhật hồ sơ B khi thử ID khác.
- Field được hỗ trợ lưu và tải lại đúng sau refresh; field không hỗ trợ được ẩn hoặc khóa, không ghi thử.
- Hồ sơ không tồn tại hoặc bị RLS từ chối có thông báo rõ và hành động retry/đăng nhập phù hợp.
- Save lỗi giữ nguyên giá trị nhập để người dùng thử lại; không báo thành công giả.
- Các thẻ Saved/Rewards và mục Settings chỉ được đưa vào phạm vi Epic 1 nếu có yêu cầu riêng và nguồn nghiệp vụ được xác định.

## Quy tắc dữ liệu và bảo mật

- Chỉ dùng Supabase URL và public/anon key phía client cùng session người dùng; không đưa service-role key, Clerk secret hoặc khóa server vào app.
- Mọi truy cập user-scoped phải dựa trên session và policy/API hiện hữu; UI filtering không thay thế kiểm soát quyền ở backend.
- Không tự thêm tài khoản, profile mapping, bảng, cột, endpoint, migration hay policy để làm session hoạt động.
- Không ghi token, mật khẩu, email verification token hoặc raw private payload vào log.
- Nếu kiến trúc hiện hữu không hỗ trợ identity/session Flutter, dừng phần tích hợp bị ảnh hưởng, lưu request/error/response đã khử bí mật và chờ quyết định phạm vi mới.

## Điều kiện hoàn tất Epic 1

- Cổng tương thích auth/identity/RLS có bằng chứng trên môi trường đã định.
- Story 1-1, 1-2, 1-3 đạt tiêu chí chấp nhận, bao gồm các trạng thái lỗi và quyền.
- Guest/user identity được phân biệt rõ; không còn dùng fallback ID như danh tính đã đăng nhập.
- Search/selection/guest draft được giữ qua auth transitions được hỗ trợ.
- `dart format`, `flutter analyze`, test phù hợp và kiểm tra thủ công luồng auth/profile trên app chạy với backend thật đều có kết quả được ghi nhận. Không dùng mock/fixture làm bằng chứng backend acceptance.

## Trạng thái hiện tại theo source review

- **1-1 — In progress / blocked:** form gọi Supabase `signUp`, `signInWithPassword`, `signOut`; compatibility với backend Clerk và RLS thật chưa xác minh.
- **1-2 — In progress:** `HotelState` chưa có trạng thái auth tập trung/listener; hiện tồn tại `guestOwnerRef` fallback cần được phân biệt với user identity.
- **1-3 — In progress / blocked:** profile screen có read/edit UI. Lookup thử ID rồi email; nhánh insert không gửi `clerk_id`, trong khi snapshot schema yêu cầu field này. Chưa chứng minh mapping và quyền profile trên môi trường chạy.

## Tài liệu/source liên quan

- `api-contract.md` — hợp đồng hiện hữu và blocker tích hợp.
- `architecture-and-state.md` — Provider/service boundary và state cần giữ.
- `business-rules.md` — quy tắc ownership và xử lý trạng thái.
- Code tham chiếu: `mobile/lib/main.dart`, `mobile/lib/providers/hotel_state.dart`, `mobile/lib/services/hotel_service.dart`, `mobile/lib/screens/auth_screen.dart`, `mobile/lib/screens/profile_screen.dart`.
- Snapshot tham chiếu: `Project/supabase/migrations/FINAL_TRIPC_SCHEMA.sql` (`public.users`); cần xác minh với môi trường thật trước khi kết luận.
