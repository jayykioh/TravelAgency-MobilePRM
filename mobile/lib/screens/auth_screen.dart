import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  final email = TextEditingController(), password = TextEditingController();
  bool register = false, busy = false;
  String message = '';
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final auth = context.read<HotelState>().service.auth;
      if (register) {
        await auth.signUp(email: email.text.trim(), password: password.text);
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
      if (mounted) {
        setState(
          () => message = auth.currentSession == null
              ? 'Kiểm tra email để xác nhận tài khoản.'
              : 'Đăng nhập thành công',
        );
      }
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(register ? 'Đăng ký' : 'Đăng nhập')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        TextField(
          controller: password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mật khẩu'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Đang xử lý…' : 'Tiếp tục'),
        ),
        TextButton(
          onPressed: () => setState(() => register = !register),
          child: Text(register ? 'Đã có tài khoản' : 'Tạo tài khoản'),
        ),
        Text(message),
        TextButton(
          onPressed: () async {
            await context.read<HotelState>().service.auth.signOut();
            if (mounted) setState(() => message = 'Đã đăng xuất');
          },
          child: const Text('Đăng xuất'),
        ),
      ],
    ),
  );
}
