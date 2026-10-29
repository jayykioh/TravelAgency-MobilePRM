# React → Flutter mapping
Paths tương đối với Project/.
| React component/page | Flutter Screen/Provider | Owner |
|---|---|---|
| app/sign-in/[[...sign-in]]/page.tsx; components/auth/AuthLayout.tsx | Login/RegisterScreen; AuthProvider | 1 |
| app/hotels/page.tsx; components/hotels/HotelHero.tsx | HotelHomeScreen; SearchProvider | 2 |
| components/hotels/HotelFilters.tsx; HotelList.tsx | Filters/HotelResultsScreen; SearchProvider | 2 |
| app/hotels/[id]/page.tsx; HotelDetailHero.tsx; HotelContent.tsx | HotelDetailScreen; HotelDetailProvider | 3 |
| components/hotels/BookingSidebar.tsx | RoomSelection/NightlyPriceSummary; HotelDetailProvider | 3 |
| app/hotel/checkout/page.tsx; components/checkout/forms/hotel-checkout-form.tsx | GuestForm/Review/ResultScreen; BookingProvider | 4 |
| app/my-bookings/page.tsx; components/bookings/BookingTabs.tsx; BookingsList.tsx; BookingCard.tsx | History/BookingDetailScreen; BookingProvider | 4 |
## Checklist
- [ ] Cam #FF5E1F, card radius 32, input/button pill, dark mode.
- [ ] Giữ nội dung và hierarchy hotel của web, chuyển layout sang mobile.
- [ ] Loading/empty/error/retry; guard giữ criteria và room sau login.
- [ ] Form giữ draft; Review khóa submit; Result hiển thị pending.

