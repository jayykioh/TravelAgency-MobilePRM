import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hotel_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.reasonMessage});

  final String? reasonMessage;

  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  bool register = false;
  bool busy = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  String? errorMessage;
  String? infoMessage;
  bool verificationSent = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  String _cleanAuthError(Object error) {
    final str = error.toString();
    if (str.contains('Invalid login credentials')) {
      return 'Email hoặc mật khẩu không chính xác.';
    }
    if (str.contains('User already registered')) {
      return 'Email này đã được đăng ký tài khoản. Vui lòng chuyển sang Đăng nhập.';
    }
    if (str.contains('Email not confirmed')) {
      return 'Email chưa được xác thực. Vui lòng kiểm tra hộp thư của bạn.';
    }
    if (str.contains('Password should be at least')) {
      return 'Mật khẩu phải có tối thiểu 6 ký tự.';
    }
    if (str.contains('rate limit') || str.contains('over_email_send_rate_limit')) {
      return 'Quá nhiều yêu cầu. Vui lòng chờ ít phút trước khi thử lại.';
    }
    if (str.contains('SocketException') ||
        str.contains('ClientException') ||
        str.contains('NetworkRequestFailed')) {
      return 'Không thể kết nối máy chủ. Vui lòng kiểm tra kết nối mạng của bạn.';
    }
    return 'Thao tác không thành công. Vui lòng kiểm tra lại thông tin và thử lại.';
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (register && password.text != confirmPassword.text) {
      setState(() {
        errorMessage = 'Mật khẩu xác nhận không khớp.';
      });
      return;
    }

    setState(() {
      busy = true;
      errorMessage = null;
      infoMessage = null;
      verificationSent = false;
    });

    try {
      final auth = context.read<HotelState>().service.auth;
      if (register) {
        final res = await auth.signUp(
          email: email.text.trim(),
          password: password.text,
        );
        if (!mounted) return;
        if (res.session == null) {
          setState(() {
            verificationSent = true;
            infoMessage =
                'Đăng ký thành công! Vui lòng kiểm tra hộp thư email (kể cả thư mục spam/rác) để xác nhận tài khoản trước khi đăng nhập.';
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng ký và tạo phiên thành công!')),
          );
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        }
      } else {
        final res = await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
        if (!mounted) return;
        if (res.session != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng nhập thành công!')),
          );
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        } else {
          setState(() {
            infoMessage = 'Vui lòng kiểm tra email để xác nhận tài khoản.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = _cleanAuthError(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotelState = context.watch<HotelState>();
    final isLoggedIn = hotelState.isAuthenticated;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAF8),
      appBar: AppBar(
        title: Text(
          register ? 'Tạo tài khoản' : 'Đăng nhập',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  // Brand Header
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5E1F), Color(0xFFF59E0B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5E1F).withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.hotel_class_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    register ? 'Bắt đầu cùng TripC' : 'Chào mừng trở lại',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.reasonMessage ??
                        (register
                            ? 'Đăng ký để lưu phòng, tích điểm và nhận ưu đãi đặc biệt.'
                            : 'Đăng nhập để xem hồ sơ và tiếp tục chuyến đi của bạn.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mode Selector Pill
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: busy
                                ? null
                                : () {
                                    setState(() {
                                      register = false;
                                      errorMessage = null;
                                      infoMessage = null;
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !register ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(99),
                                boxShadow: !register
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Đăng nhập',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight:
                                      !register ? FontWeight.w800 : FontWeight.w600,
                                  color: !register
                                      ? const Color(0xFFFF5E1F)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: busy
                                ? null
                                : () {
                                    setState(() {
                                      register = true;
                                      errorMessage = null;
                                      infoMessage = null;
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: register ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(99),
                                boxShadow: register
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'Đăng ký',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight:
                                      register ? FontWeight.w800 : FontWeight.w600,
                                  color: register
                                      ? const Color(0xFFFF5E1F)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error / Info banners
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFDC2626), size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFF991B1B),
                                fontSize: 13,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (infoMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: verificationSent
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: verificationSent
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFFFCD34D),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            verificationSent
                                ? Icons.mark_email_read_outlined
                                : Icons.info_outline,
                            color: verificationSent
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              infoMessage!,
                              style: TextStyle(
                                color: verificationSent
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF92400E),
                                fontSize: 13,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Input
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: 'Địa chỉ Email',
                      hintText: 'ten@example.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide:
                            const BorderSide(color: Color(0xFFFF5E1F), width: 1.8),
                      ),
                    ),
                    validator: (val) {
                      final text = val?.trim() ?? '';
                      if (text.isEmpty) return 'Vui lòng nhập email.';
                      final emailRegex =
                          RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$');
                      if (!emailRegex.hasMatch(text)) {
                        return 'Email không hợp lệ.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  TextFormField(
                    controller: password,
                    obscureText: obscurePassword,
                    textInputAction:
                        register ? TextInputAction.next : TextInputAction.done,
                    onFieldSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      hintText: 'Ít nhất 6 ký tự',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide:
                            const BorderSide(color: Color(0xFFFF5E1F), width: 1.8),
                      ),
                    ),
                    validator: (val) {
                      final text = val ?? '';
                      if (text.isEmpty) return 'Vui lòng nhập mật khẩu.';
                      if (text.length < 6) {
                        return 'Mật khẩu phải có ít nhất 6 ký tự.';
                      }
                      return null;
                    },
                  ),

                  // Confirm Password for Registration
                  if (register) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPassword,
                      obscureText: obscureConfirmPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: 'Xác nhận mật khẩu',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() =>
                              obscureConfirmPassword = !obscureConfirmPassword),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              const BorderSide(color: Color(0xFFFF5E1F), width: 1.8),
                        ),
                      ),
                      validator: (val) {
                        if (register && (val == null || val.isEmpty)) {
                          return 'Vui lòng nhập lại mật khẩu.';
                        }
                        if (register && val != password.text) {
                          return 'Mật khẩu xác nhận không khớp.';
                        }
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Submit Button
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5E1F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                        elevation: 2,
                      ),
                      onPressed: busy ? null : submit,
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              register ? 'Đăng ký tài khoản' : 'Đăng nhập ngay',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Switch between login and register
                  Center(
                    child: TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              setState(() {
                                register = !register;
                                errorMessage = null;
                                infoMessage = null;
                              });
                            },
                      child: RichText(
                        text: TextSpan(
                          text: register
                              ? 'Đã có tài khoản TripC? '
                              : 'Chưa có tài khoản? ',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: register ? 'Đăng nhập' : 'Tạo tài khoản',
                              style: const TextStyle(
                                color: Color(0xFFFF5E1F),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Sign out button - ONLY shown when an active session exists
                  if (isLoggedIn) ...[
                    const SizedBox(height: 28),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 14),
                    Center(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed: busy
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Xác nhận đăng xuất'),
                                    content: const Text(
                                        'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Hủy'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFDC2626),
                                        ),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Đăng xuất'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && mounted) {
                                  await hotelState.service.auth.signOut();
                                  if (mounted) {
                                    setState(() {
                                      infoMessage = 'Đã đăng xuất thành công.';
                                      errorMessage = null;
                                    });
                                  }
                                }
                              },
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text(
                          'Đăng xuất phiên hiện tại',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
