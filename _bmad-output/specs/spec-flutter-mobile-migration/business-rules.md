# Business rules migration
- Giữ city/ngày/số khách xuyên luồng; checkout sau check-in, số đêm không tính ngày checkout.
- Room thuộc hotel đã chọn; số khách không vượt capacity nguồn.
- Giá từng đêm/currency/tax/fee map logic hiện hữu; không đặt tỷ lệ hoặc API giá mới.
- Form validate tên/email/điện thoại và giữ draft khi Back.
- Khóa submit khi đang gửi, không retry mutation tự động khi timeout.
- Chỉ báo thành công khi có ID thật; đơn pending/chờ xác nhận, chưa thanh toán.
- History phải dùng session và quyền chủ sở hữu thực tế.
- Không hứa atomic inventory, idempotency hoặc server price validation khi chưa có ở hệ thống hiện hữu.

