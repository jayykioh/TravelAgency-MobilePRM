import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/hotel_state.dart';
import 'package:mobile/screens/hotel_home_screen.dart';
import 'package:mobile/widgets/filter_section.dart';
import 'package:provider/provider.dart';

class FakeHotelState extends HotelState {
  @override
  Future<List<Map<String, dynamic>>> hotels() async => [
    {
      'id': 'hotel-1',
      'name': 'Demo Hotel',
      'best_price': 6200,
      'images': const [],
      'address': {'city': 'Đà Nẵng'},
    },
  ];

  @override
  String day(DateTime value) => value.toIso8601String().substring(0, 10);
}

void main() {
  testWidgets('date field opens date range picker', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<HotelState>.value(
        value: FakeHotelState(),
        child: const MaterialApp(home: Home()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('NHẬN — TRẢ PHÒNG'));
    await tester.pumpAndSettle();

    expect(find.byType(DateRangePickerDialog), findsOneWidget);
  });

  testWidgets('search button shows result feedback', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<HotelState>.value(
        value: FakeHotelState(),
        child: const MaterialApp(home: Home()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tìm khách sạn'));
    await tester.pumpAndSettle();

    expect(find.text('Tìm thấy 1 khách sạn phù hợp'), findsOneWidget);
  });

  testWidgets('HotelFilterSheet allows toggling filters and resetting', (
    tester,
  ) async {
    final state = FakeHotelState()..stars.add(5);
    expect(state.hasActiveFilters, isTrue);
    expect(state.activeFiltersCount, 1);

    await tester.pumpWidget(
      ChangeNotifierProvider<HotelState>.value(
        value: state,
        child: const MaterialApp(
          home: Scaffold(body: HotelFilterSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bộ lọc tìm kiếm'), findsOneWidget);
    expect(find.text('Hạng sao khách sạn'), findsOneWidget);
    expect(find.text('Thiết lập lại'), findsOneWidget);

    // Tap reset in filter sheet
    await tester.tap(find.text('Thiết lập lại'));
    await tester.pumpAndSettle();

    expect(state.hasActiveFilters, isFalse);
    expect(state.stars, isEmpty);
  });
}
