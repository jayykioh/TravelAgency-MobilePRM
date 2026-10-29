# Data adapters dùng nguồn hiện hữu
| Nhu cầu | Nguồn React/Next.js | Flutter |
|---|---|---|
| Auth | lib/hotel/clerkAuth.ts; BookingSidebar và checkout form dùng Clerk | Supabase Auth theo yêu cầu; compatibility chưa xác minh |
| Search | HotelList.tsx gọi GET /api/hotels | HotelService.search |
| Detail/rooms/rates | app/api/hotels/[slug]/route.ts, rooms/route.ts, rates/route.ts | HotelService.detail/rooms/rates |
| Form data | hotel-checkout-form.tsx query Supabase hotels/rooms | SDK query dưới quyền hiện hữu |
| Create pending | /api/checkout/initialize gọi CheckoutService; /api/hotels/bookings yêu cầu Clerk | BookingService.createPending qua thao tác hiện hữu tương thích |
| History | app/my-bookings/page.tsx gọi /api/bookings/user | BookingService.list/detail |
## Gate Member 1 — sáng ngày 1
- [ ] Supabase Auth đã bật và register/login thực sự hoạt động.
- [ ] Kiểm tra session Supabase có được API chấp nhận không; JWT Supabase không mặc nhiên thay được Clerk.
- [ ] SDK fallback chỉ khi RLS hiện hữu cho phép đọc/ghi đúng chủ sở hữu.
- [ ] Kiểm tra create pending trả ID và history đọc được mà không cần payment settlement.
- [ ] Nếu API và SDK đều không hỗ trợ: ghi blocker chính xác; không tạo endpoint/schema/policy/auth mới.
Không có contract /api/mobile/v1 mới, không server JWT riêng, không migration/seed và không dùng server secrets trong Flutter.

