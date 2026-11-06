import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';
import '../services/payment_service.dart';
import '../widgets/payment_bottom_sheet.dart';
import 'ai_chat_screen.dart';
import 'hotel_bookings_screen.dart';
import 'hotel_home_screen.dart';
import 'hotels_map_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

/// Main navigation exposes every PRM393-scored feature from one Flutter flow.
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSub;

  static const pages = <Widget>[
    Home(),
    HotelsMapScreen(),
    HistoryScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initPaymentDeepLinks();
  }

  Future<void> _initPaymentDeepLinks() async {
    try {
      _appLinks = AppLinks();
      final initialUri = await _appLinks?.getInitialLink();
      if (initialUri != null) {
        _handlePaymentLink(initialUri);
      } else if (kIsWeb) {
        final current = Uri.base;
        if (current.queryParameters.containsKey('token') ||
            current.queryParameters.containsKey('resultCode') ||
            current.queryParameters.containsKey('PayerID')) {
          _handlePaymentLink(current);
        }
      }
      _linkSub = _appLinks?.uriLinkStream.listen(
        _handlePaymentLink,
        onError: (err) => debugPrint('AppShell deep link error: $err'),
      );
    } catch (e) {
      debugPrint('AppShell deep links init error: $e');
    }
  }

  Future<void> _handlePaymentLink(Uri uri) async {
    final isCallback = (uri.scheme == 'io.supabase.tripc' &&
            (uri.host == 'payment-callback' ||
                uri.path.contains('payment-callback'))) ||
        (kIsWeb &&
            (uri.queryParameters.containsKey('token') ||
                uri.queryParameters.containsKey('resultCode') ||
                uri.queryParameters.containsKey('PayerID')));

    if (isCallback) {
      if (PaymentBottomSheet.wasRecentlyHandled()) {
        return;
      }

      final status = uri.queryParameters['status'];
      if (status == 'cancelled') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Giao dịch thanh toán đã bị huỷ.'),
              backgroundColor: Color(0xFFE11D48),
            ),
          );
        }
        return;
      }

      final resultCode = uri.queryParameters['resultCode'];
      if (resultCode != null && resultCode != '0') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Thanh toán thất bại (mã $resultCode).'),
              backgroundColor: const Color(0xFFE11D48),
            ),
          );
        }
        return;
      }

      final bookingId = uri.queryParameters['bookingId'];
      final provider = uri.queryParameters['provider'] ?? 'paypal';
      final payerId =
          uri.queryParameters['PayerID'] ?? uri.queryParameters['payerId'];
      final token = uri.queryParameters['token'];
      final orderId = uri.queryParameters['orderId'];
      final txnId = payerId ?? token ?? orderId;

      if (bookingId != null && bookingId.isNotEmpty) {
        try {
          final state = context.read<HotelState>();
          final paymentService = PaymentService(state.service.client);

          await paymentService.markBookingPaid(
            bookingId: bookingId,
            provider: provider,
            txnId: txnId,
          );

          if (mounted) {
            setState(() {
              index = 2; // Jump to Bookings history tab!
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Color(0xFF16A34A),
                duration: Duration(seconds: 4),
                content: Text(
                  'Thanh toán thành công! Đơn đặt phòng của bạn đã được xác nhận.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error marking booking paid in AppShell: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: index, children: pages),
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'tripc-ai',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AiChatScreen()),
      ),
      icon: const Icon(Icons.auto_awesome),
      label: const Text('AI Chat'),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) => setState(() => index = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.hotel_outlined),
          selectedIcon: Icon(Icons.hotel),
          label: 'Hotels',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Map',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Bookings',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    ),
  );
}
