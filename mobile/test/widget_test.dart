import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  test('Hotel stay counts nights without checkout day', () {
    final state = HotelState()
      ..start = DateTime(2026, 11, 10)
      ..end = DateTime(2026, 11, 12);
    expect(state.nights, 2);
  });
  testWidgets('Missing configuration never displays mock hotel data', (
    tester,
  ) async {
    await tester.pumpWidget(const HotelApp());
    expect(find.textContaining('Chưa cấu hình Supabase'), findsOneWidget);
    expect(find.text('TripC Riverside Đà Nẵng'), findsNothing);
  });
}
