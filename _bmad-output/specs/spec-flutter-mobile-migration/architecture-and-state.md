# Flutter architecture
Screens → ChangeNotifier/Provider → Services/Repositories → Supabase SDK hoặc API hiện hữu.
Member 1: app/, core/, clients, router, session và models chung.
Member 2: features/discovery; Member 3: features/hotel_detail; Member 4: features/booking.
Models: UserSession, SearchCriteria, Hotel, Room, NightlyPrice, Quote, BookingDraft, Booking.
Provider giữ criteria, selected room/quote, draft, loading/error. View không gọi SDK trực tiếp.
Ngày 1 UI tĩnh dùng preview cục bộ widget; ngày 2 bỏ preview khỏi runtime và nghiệm thu bằng dữ liệu thật.
Supabase chỉ dùng URL + publishable/anon key và session. Không service-role.

