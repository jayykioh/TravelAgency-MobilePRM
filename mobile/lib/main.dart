import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/hotel_state.dart';
import 'screens/app_shell.dart';

export 'providers/hotel_state.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL'),
);
const supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    defaultValue: String.fromEnvironment('NEXT_PUBLIC_SUPABASE_KEY'),
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => HotelState(),
      child: const HotelApp(),
    ),
  );
}

class HotelApp extends StatelessWidget {
  const HotelApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TripC Hotels',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFFFF5E1F),
      scaffoldBackgroundColor: const Color(0xFFFCFAF8),
      useMaterial3: true,
    ),
    home: supabaseUrl.isEmpty || supabaseAnonKey.isEmpty
        ? const MissingConfigurationScreen()
        : const AppShell(),
  );
}

class MissingConfigurationScreen extends StatelessWidget {
  const MissingConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Chưa cấu hình Supabase. Hãy cung cấp SUPABASE_URL và SUPABASE_ANON_KEY.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
    ),
  );
}
