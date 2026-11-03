import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/hotel_state.dart';
import 'package:mobile/screens/auth_screen.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:provider/provider.dart';

void main() {
  group('HotelState Auth and Draft State', () {
    test('guest state reflects unauthenticated and provides distinct guest owner ref', () {
      final state = HotelState();
      expect(state.isAuthenticated, isFalse);
      expect(state.isGuestBooking, isTrue);
      expect(state.currentUser, isNull);
      expect(state.bookingOwnerRef, startsWith('DEMO-'));
      expect(state.authenticatedUserId, isEmpty);
    });

    test('guest checkout draft retains fields and clears accurately', () {
      final state = HotelState();
      expect(state.draftGuestName, isEmpty);

      state.saveGuestDraft(
        name: 'Nguyen Van A',
        email: 'nguyenvana@example.com',
        phone: '0901234567',
        specialRequests: 'High floor, quiet room',
        voucherCode: 'TRIPC2026',
      );

      expect(state.draftGuestName, 'Nguyen Van A');
      expect(state.draftGuestEmail, 'nguyenvana@example.com');
      expect(state.draftGuestPhone, '0901234567');
      expect(state.draftSpecialRequests, 'High floor, quiet room');
      expect(state.draftVoucherCode, 'TRIPC2026');

      state.clearGuestDraft();
      expect(state.draftGuestName, isEmpty);
      expect(state.draftGuestEmail, isEmpty);
      expect(state.draftGuestPhone, isEmpty);
      expect(state.draftSpecialRequests, isEmpty);
      expect(state.draftVoucherCode, isEmpty);
    });
  });

  group('AuthScreen Widget Tests', () {
    testWidgets('renders login form by default and toggles to register mode', (
      tester,
    ) async {
      final state = HotelState();
      await tester.pumpWidget(
        ChangeNotifierProvider<HotelState>.value(
          value: state,
          child: const MaterialApp(home: AuthScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập'), findsWidgets);
      expect(find.text('Chào mừng trở lại'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Email and Password

      // Switch to Register mode
      await tester.tap(find.text('Đăng ký').first);
      await tester.pumpAndSettle();

      expect(find.text('Bắt đầu cùng TripC'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3)); // Email, Password, Confirm Password
    });

    testWidgets('client-side email validation warns on invalid input', (
      tester,
    ) async {
      final state = HotelState();
      await tester.pumpWidget(
        ChangeNotifierProvider<HotelState>.value(
          value: state,
          child: const MaterialApp(home: AuthScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap submit with empty fields
      await tester.tap(find.text('Đăng nhập ngay'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập email.'), findsOneWidget);
      expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);
    });
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets('shows guest preview view with login button when not authenticated', (
      tester,
    ) async {
      final state = HotelState();
      await tester.pumpWidget(
        ChangeNotifierProvider<HotelState>.value(
          value: state,
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
      expect(find.text('Chào mừng bạn đến với TripC'), findsOneWidget);
      expect(find.text('Đăng nhập / Đăng ký'), findsOneWidget);
      expect(find.text('Lợi ích thành viên TripC'), findsOneWidget);
    });
  });
}

