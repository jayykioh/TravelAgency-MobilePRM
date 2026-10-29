# Kế hoạch 3 ngày — 4 Flutter owners
| Owner | Sở hữu | Bàn giao |
|---|---|---|
| Member 1 Core/Data/Auth | mobile/app, core, shared models/services, Provider, Auth | Client/session/router và models chung |
| Member 2 Discovery/Search | HotelHome, filters, results | SearchCriteria + hotel được chọn |
| Member 3 Detail/Rooms | Detail, rooms, nightly prices | Selected room + quote |
| Member 4 Booking/History | Form, Review, create pending, history/detail | Booking ID + trạng thái thật |
## Lịch thực thi
| Mốc | Member 1 | Member 2 | Member 3 | Member 4 | Gate |
|---|---|---|---|---|---|
| Ngày 1 sáng | Khởi tạo Flutter; kiểm tra Auth/RLS/API; chốt models/services | Map home/filter/list; UI tĩnh | Map detail/sidebar; UI phòng | Map checkout/history; UI form/review |
| Ngày 1 chiều | Auth thật, clients, providers/router | Hoàn chỉnh UI search/results | Hoàn chỉnh UI detail/quote | UI review/result/history/detail | Auth hoạt động, UI toàn bộ 6 bước ghép chung |
| Ngày 2 sáng | Hoàn thiện adapter/session | Nối search data | Nối detail/rates | Nối create pending/history | 12:00 Search→Detail thật |
| Ngày 2 chiều | Fix tích hợp data/auth | Fix filters/pagination | Fix room/price selection | Hoàn tất submit/history | **18:00 full P0 chạy đầu-cuối** |
| Ngày 3 sáng | Fix auth/data/loading/error | Fix search; P1 nếu dư | Fix detail; Map nếu dư | Fix booking; Notifications/Chat nếu dư | **12:00 code freeze** |
| Ngày 3 chiều | Test chéo Booking, build APK | Test chéo Auth | Test chéo Search | Test chéo Detail | APK cài/chạy emulator hoặc máy thật |
## Checklist
- [ ] Sáng ngày 1 Member 1 chốt UserSession, SearchCriteria, Hotel, Room, NightlyPrice, Quote, BookingDraft, Booking và service signatures.
- [ ] Mỗi người sở hữu feature Flutter, tự test phần mình; không có owner backend/QA thuần túy.
- [ ] Handoff: criteria → selected hotel → room/quote → booking draft → booking ID.
- [ ] P0 trễ 18:00 ngày 2: cắt toàn bộ Map/Notifications/Chat.
- [ ] P1 chỉ dùng nguồn hiện hữu và hoàn tất trước freeze; không thay đổi backend để hỗ trợ.
- [ ] Format, flutter analyze, flutter test đạt; test ngày/số khách, double-tap, loading/empty/error.
- [ ] Test chéo đủ 6 bước, mất mạng, Back, logout, quyền sở hữu đơn.
- [ ] Build/cài APK và chạy dữ liệu thật; không đưa báo cáo, slide, video, analyze-size vào lịch.

