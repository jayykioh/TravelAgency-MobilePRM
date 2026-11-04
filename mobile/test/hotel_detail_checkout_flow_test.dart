import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/hotel_insight.dart';
import 'package:mobile/models/hotel_review.dart';
import 'package:mobile/models/room_quote.dart';
import 'package:mobile/providers/hotel_state.dart';
import 'package:mobile/screens/booking_review_screen.dart';
import 'package:mobile/screens/hotel_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const hotel = <String, dynamic>{
  'id': 'hotel-1',
  'name': 'Demo Resort',
  'description': 'Beachfront resort.',
  'star_rating': 5,
  'images': <String>[],
  'amenities': ['Pool', 'Spa'],
  'policies': {'check_in': '14:00'},
  'address': {'line1': 'Khem Beach', 'city': 'Phu Quoc'},
  'best_price': 6200,
  'average_rating': 0,
  'review_count': 0,
};

class FakeFlowState extends HotelState {
  FakeFlowState({this.signedIn = true, this.createError});

  bool signedIn;
  Object? createError;
  Map<String, dynamic>? lastPayload;
  int createCalls = 0;

  @override
  bool get isAuthenticated => signedIn;
  @override
  String get authenticatedUserId => signedIn ? 'auth-user-1' : '';
  @override
  String day(DateTime value) => isoDay(value);

  @override
  Future<List<RoomOption>> roomOptionsFor(Map<String, dynamic> hotel) async {
    RoomQuote? q(Map<String, dynamic> room, List<Map<String, dynamic>> rates) =>
        buildRoomQuote(
          room: room,
          rates: rates,
          start: DateUtils.dateOnly(start),
          end: DateUtils.dateOnly(end),
          roomCount: rooms,
          guestCount: totalGuests,
          hotelBestPriceCents: hotel['best_price'] as num?,
        );
    const deluxe = {'id': 'room-1', 'title': 'Deluxe King', 'capacity': 2};
    const suite = {'id': 'room-2', 'title': 'Ocean Suite', 'capacity': 4};
    return [
      RoomOption(room: deluxe, quote: q(deluxe, const [])),
      RoomOption(
        room: suite,
        quote: q(suite, [
          {
            'id': 'x',
            'date': '2026-01-01',
            'price_cents': 20000,
            'partner_id': 'p1',
            'available_rooms': 1,
            'currency': 'USD',
          },
        ]),
      ),
    ];
  }

  @override
  Future<List<HotelReview>> reviewsFor(String hotelId) async => [
    HotelReview.fromJson({
      'id': 'rv1',
      'rating': 4,
      'title': 'Lovely',
      'comment': 'Great stay',
    }),
  ];

  @override
  Future<HotelInsight?> insightsFor(Map<String, dynamic> hotel) async =>
      const HotelInsight(title: 'AI Insight: Couples', mainInsight: 'Sunset.');

  @override
  Future<Map<String, dynamic>?> currentProfile() async => null;

  @override
  Future<Map<String, dynamic>> createBooking(
    Map<String, dynamic> payload,
  ) async {
    createCalls++;
    lastPayload = payload;
    if (createError != null) throw createError!;
    return {
      'id': 'booking-123',
      'confirmation_code': payload['confirmation_code'],
      'status': 'pending',
      'payment_status': 'pending',
      'total_cents': payload['total_cents'],
      'currency': payload['currency'],
    };
  }
}

Future<void> pumpDetail(WidgetTester tester, FakeFlowState state) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<HotelState>.value(
      value: state,
      child: const MaterialApp(home: DetailScreen(hotel: hotel)),
    ),
  );
  await tester.pumpAndSettle();
}

final vertical = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: vertical.last);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> fillGuestForm(WidgetTester tester) async {
  await tester.enterText(find.byKey(const ValueKey('guest-name')), 'Lan Anh');
  await tester.enterText(
    find.byKey(const ValueKey('guest-email')),
    'lan@tripc.vn',
  );
  await tester.enterText(
    find.byKey(const ValueKey('guest-phone')),
    '0912345678',
  );
}

Future<void> tapContinue(WidgetTester tester) async {
  final button = find.text('Tiếp tục xem lại');
  await scrollTo(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> chooseSuite(WidgetTester tester) async {
  await scrollTo(tester, find.text('Ocean Suite'));
  await tester.drag(vertical.last, const Offset(0, -400));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Chọn').last);
  await tester.pumpAndSettle();
}

Future<void> selectSuiteAndReserve(WidgetTester tester) async {
  await chooseSuite(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'Đặt phòng'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeFlowState state;

  setUp(() {
    state = FakeFlowState()
      ..start = DateTime(2026, 12, 10)
      ..end = DateTime(2026, 12, 12);
  });

  testWidgets('detail shows content, insight, reviews and reference prices', (
    tester,
  ) async {
    await pumpDetail(tester, state);
    expect(find.text('Demo Resort'), findsWidgets);
    expect(find.text('Khem Beach, Phu Quoc'), findsOneWidget);
    expect(find.text('Sunset.'), findsOneWidget);
    await scrollTo(tester, find.text('Great stay'));
    expect(find.text('Great stay'), findsOneWidget);
    await scrollTo(tester, find.text('Ocean Suite'));
    expect(find.textContaining('Giá tham khảo'), findsWidgets);
    // Reserve bar disabled until a room is picked.
    expect(find.text('Chọn một phòng để tiếp tục'), findsOneWidget);
  });

  testWidgets('selecting a room updates the reserve summary', (tester) async {
    await pumpDetail(tester, state);
    await chooseSuite(tester);
    expect(state.selectedQuote?.roomId, 'room-2');
    // 2 nights × $200 = $400; +10% +5% = $460.00
    expect(find.text('\$460.00'), findsOneWidget);
    expect(find.text('Đã chọn'), findsOneWidget);

    // Changing the stay drops the stale quote.
    state.updateGuestConfig(roomCount: 2);
    await tester.pumpAndSettle();
    expect(state.selectedQuote, isNull);
    expect(find.text('Chọn một phòng để tiếp tục'), findsOneWidget);
  });

  testWidgets('guest form validates and keeps the draft on back', (
    tester,
  ) async {
    await pumpDetail(tester, state);
    await selectSuiteAndReserve(tester);
    await tapContinue(tester);
    expect(find.text('Vui lòng nhập họ tên'), findsOneWidget);
    expect(find.text('Vui lòng nhập email'), findsOneWidget);

    await fillGuestForm(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(state.draftGuestName, 'Lan Anh');

    await tester.tap(find.widgetWithText(FilledButton, 'Đặt phòng'));
    await tester.pumpAndSettle();
    expect(find.text('Lan Anh'), findsOneWidget);
    expect(find.text('0912345678'), findsOneWidget);
  });

  testWidgets('review submits once and shows the real backend id', (
    tester,
  ) async {
    await pumpDetail(tester, state);
    await selectSuiteAndReserve(tester);
    await fillGuestForm(tester);
    await tapContinue(tester);

    expect(find.byType(BookingReviewScreen), findsOneWidget);
    expect(find.text('Thuế (10%)'), findsOneWidget);
    expect(find.text('Phí dịch vụ (5%)'), findsOneWidget);

    final submit = find.text('Gửi yêu cầu đặt phòng');
    await scrollTo(tester, submit);
    expect(find.textContaining('Chưa thanh toán'), findsWidgets);
    expect(find.textContaining('Giá tham khảo'), findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(state.createCalls, 1);
    expect(state.lastPayload!['user_uuid'], 'auth-user-1');
    expect(state.lastPayload!['total_cents'], 46000);
    expect(find.byType(BookingResultScreen), findsOneWidget);
    expect(find.text('booking-123'), findsOneWidget);
    expect(find.text('Chờ xác nhận'), findsOneWidget);
    expect(state.draftGuestName, isEmpty);
    expect(state.selectedQuote, isNull);
  });

  testWidgets('RLS denial keeps the user on review with an actionable error', (
    tester,
  ) async {
    state.createError = const PostgrestException(
      message: 'new row violates row-level security policy',
      code: '42501',
    );
    await pumpDetail(tester, state);
    await selectSuiteAndReserve(tester);
    await fillGuestForm(tester);
    await tapContinue(tester);
    final submit = find.text('Gửi yêu cầu đặt phòng');
    await scrollTo(tester, submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byType(BookingResultScreen), findsNothing);
    expect(find.byKey(const ValueKey('booking-error')), findsOneWidget);
    expect(find.textContaining('row-level security'), findsNothing);
    final code = state.pendingConfirmationCode;
    expect(code, isNotNull);

    // Retrying reuses the same confirmation code (dedupe on unique code).
    await scrollTo(tester, submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(state.createCalls, 2);
    expect(state.lastPayload!['confirmation_code'], code);
    expect(state.draftGuestName, 'Lan Anh');
  });
}
