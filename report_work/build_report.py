from copy import deepcopy
from pathlib import Path
from docx import Document
from docx.shared import Inches

root = Path(r'D:\PRMCapstone\TravelAgency-MobilePRM')
source = root / 'report_template_source.docx'
target = root / 'TRIPC_MOBILE_TECHNICAL_REPORT.docx'
doc = Document(source)

def put(paragraph, value):
    if paragraph.runs:
        paragraph.runs[0].text = value
        for run in paragraph.runs[1:]:
            run.text = ''
    else:
        paragraph.add_run(value)

def cell(table, row, col, value):
    put(table.cell(row, col).paragraphs[0], value)
    for p in table.cell(row, col).paragraphs[1:]:
        put(p, '')

p = doc.paragraphs
values = {
    0: 'TECHNICAL REPORT: MOBILE TRAVEL BOOKING APPLICATION',
    1: 'Course: Flutter Application Development',
    2: 'Team Size: 4 Members',
    3: 'Project Name: TripC Hotels',
    8: 'Project Title: TripC Hotels - Ứng dụng di động tìm kiếm và gửi yêu cầu đặt phòng khách sạn.',
    9: 'Domain: Travel Booking / Hotel Reservation.',
    11: 'TripC Hotels là ứng dụng Flutter tham chiếu trải nghiệm đặt khách sạn của TripC trên web. Người dùng tìm khách sạn, xem phòng và giá theo ngày, nhập thông tin khách và gửi yêu cầu đặt phòng ở trạng thái chờ xác nhận, chưa thanh toán. Ứng dụng có bản đồ, lịch sử đặt phòng, thông báo, hồ sơ, AI chat và Tcent/voucher. Flutter truy cập dữ liệu qua Supabase và gọi một số API Next.js hiện hữu. Tương thích giữa phiên Supabase Auth của mobile với backend dùng Clerk và RLS vẫn cần xác minh trên môi trường thật.',
    15: 'Functional Requirements: Đăng nhập/đăng ký, hồ sơ, tìm và lọc khách sạn, xem phòng/giá, bản đồ, nhập thông tin khách, gửi yêu cầu đặt phòng, xem/hủy đơn, thông báo, AI chat và voucher.',
    17: 'Hiệu năng: Có trạng thái tải, lỗi và thử lại; chưa đo hoặc cam kết thời gian tải cố định.',
    18: 'Bảo mật: Dùng public key Supabase và quyền phiên người dùng; không đặt khóa bí mật server trong app.',
    19: 'Tính khả dụng: Giao diện Flutter theo luồng đặt phòng; form kiểm tra dữ liệu và giữ ngữ cảnh giữa các bước.',
    21: 'Nhóm sử dụng Provider/ChangeNotifier kết hợp với kiến trúc phân lớp:',
    22: 'UI Layer: Các Screen và Widget hiển thị tìm kiếm, chi tiết, checkout, bản đồ và tài khoản.',
    23: 'Business Logic Layer (Provider): HotelState giữ trạng thái tìm kiếm, phòng chọn và luồng đặt phòng; model tính giá.',
    24: 'Data Layer: HotelService/VoucherService truy cập Supabase và API Next.js hiện hữu.',
    25: '3.3. Database Design (Supabase / PostgreSQL)',
    26: 'Bảng hotel_bookings (các trường app sử dụng):',
    29: 'OpenStreetMap / flutter_map: Hiển thị vị trí khách sạn từ tọa độ trong dữ liệu.',
    30: 'Supabase Flutter: Xác thực và truy cập PostgreSQL; Next.js API phục vụ AI chat và hotel insights.',
    34: 'State Management: ChangeNotifierProvider tạo HotelState ở main.dart; IndexedStack giữ các tab chính.',
    35: 'Remote Data: HotelService đọc hotels, hotel_rooms, hotel_rates và ghi yêu cầu vào hotel_bookings.',
    36: 'Remote Auth: Flutter dùng Supabase Auth; mapping với Clerk/users.id và quyền RLS cần xác minh.',
    38: 'Unit Test: Có test model khách sạn, báo giá phòng, payload đặt phòng và voucher.',
    39: 'Widget Test: Có test auth/profile, trang khách sạn và luồng detail → checkout; cần kiểm tra backend thật.',
    41: 'Build Mode: Mục tiêu release APK sau khi acceptance pass (flutter build apk --release).',
    42: 'Proof: Chưa có bằng chứng release APK đã cài và chạy trên Android; nhóm cần đính kèm log build, APK và ảnh/video kiểm thử khi nộp.',
    45: 'Database/API Structure: Supabase hotels, hotel_rooms, hotel_rates, hotel_bookings và API Next.js hiện hữu.',
    46: 'Login Screen: Đăng ký/đăng nhập bằng Supabase Auth; kiểm tra quyền với backend thật.',
    47: 'Hotel List: Tìm khách sạn theo địa điểm, ngày, số khách và các bộ lọc.',
    48: 'Hotel Detail: Xem ảnh, tiện nghi, đánh giá, phòng và giá chính xác/giá tham khảo.',
    49: 'Booking History: Xem yêu cầu đặt phòng và hủy đơn đang chờ khi backend cho phép.',
    50: 'Checkout Screen: Nhập thông tin khách, xem tiền phòng, thuế 10%, phí 5% và gửi yêu cầu pending.',
    51: 'Notifications: Xem thông báo theo tài khoản và đánh dấu đã đọc.',
    52: 'Map Screen: Hiển thị vị trí khách sạn trên OpenStreetMap.',
    53: 'Messaging Screen: AI chat gọi route Next.js hiện hữu; phản hồi phụ thuộc phiên và backend.',
    54: 'State Management: HotelState giữ ngữ cảnh tìm kiếm, phòng và form qua các màn hình.',
    57: 'Pros: Có mã nguồn cho luồng đặt khách sạn; tách UI, state, model và service; xử lý giá theo đêm và lỗi form.',
    58: 'Cons: Supabase Auth chưa được chứng minh tương thích Clerk/RLS; chưa có release APK xác minh; không thanh toán online; voucher có dữ liệu dự phòng.',
    59: 'Learning: Kết hợp Flutter, Provider, Supabase, API hiện hữu, tính giá theo cent và kiểm thử luồng đặt phòng.',
    60: 'Future Improvements: Xác minh mapping định danh/RLS, kiểm thử backend thật, phân trang tìm kiếm và build APK release.',
    65: 'Flutter Documentation: https://docs.flutter.dev/',
    66: 'Supabase Flutter: https://supabase.com/docs/reference/dart/introduction',
    67: 'Provider Package: https://pub.dev/packages/provider',
    68: 'flutter_map: https://docs.fleaflet.dev/',
}
for i, value in values.items():
    put(p[i], value)

# Reuse the source table row format for the fourth member.
t = doc.tables[0]
new_row = deepcopy(t.rows[-1]._tr)
t._tbl.append(new_row)
members = ['Đoàn Trọng Lực', 'Võ Hà Đông', 'Nguyễn Vũ Hoàng', 'Phạm Tuấn Huy']
for i, name in enumerate(members, 1):
    for j, v in enumerate([name, 'Team Member', 'Phân tích, phát triển, kiểm thử và viết báo cáo theo phân công nhóm', '25%']):
        cell(t, i, j, v)

# Keep the database table's four-column visual layout, replacing Cart fields.
t = doc.tables[1]
db_rows = [
    ['Tên cột', 'Kiểu dữ liệu', 'Ràng buộc', 'Giải thích'],
    ['id', 'UUID', 'PRIMARY KEY', 'Mã đơn thật do backend trả về.'],
    ['user_uuid', 'UUID', 'FK users(id)', 'Tài khoản sở hữu yêu cầu đặt phòng.'],
    ['hotel_id', 'UUID', 'FK hotels(id)', 'Khách sạn được chọn.'],
    ['room_id', 'UUID', 'FK hotel_rooms(id)', 'Phòng được chọn.'],
    ['check_in_date', 'DATE', 'Bắt buộc', 'Ngày nhận phòng.'],
    ['check_out_date', 'DATE', 'Bắt buộc', 'Ngày trả phòng.'],
    ['total_cents', 'INTEGER', 'Bắt buộc', 'Tổng tiền theo cent; trạng thái đơn pending.'],
]
for i, row in enumerate(db_rows):
    for j, v in enumerate(row): cell(t, i, j, v)

# Add the fourth name column while retaining the source contribution table.
t = doc.tables[2]
t.add_column(Inches(0.93))
contrib = [
    ['Topic', 'Effort', *members],
    ['Case Study Analysis', '100%', '25%', '25%', '25%', '25%'],
    ['Business Analysis', '100%', '25%', '25%', '25%', '25%'],
    ['System Design', '100%', '25%', '25%', '25%', '25%'],
    ['Implementation', '100%', '25%', '25%', '25%', '25%'],
    ['Documentation', '100%', '25%', '25%', '25%', '25%'],
]
for i, row in enumerate(contrib):
    for j, v in enumerate(row): cell(t, i, j, v)
# The reference table occupies the page width; redistribute existing columns.
widths = [Inches(1.55), Inches(0.65), Inches(0.93), Inches(0.93), Inches(0.93), Inches(0.93)]
for row in t.rows:
    for j, width in enumerate(widths): row.cells[j].width = width

doc.save(target)
print(target)
