import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:litera2/fitur/auth/service/service_auth.dart';
import 'package:litera2/core/konstan/warna_aplikasi.dart';
import 'package:litera2/core/tema/tema_aplikasi.dart';
import 'package:litera2/global/widget/elemen_custom.dart';
import 'package:litera2/fitur/auth/halaman/halaman_register.dart';
import 'package:litera2/main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isObscured = true;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ================= RESET PASSWORD =================
  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Kata Sandi'),
          content: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Masukkan email Anda'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                FocusScope.of(context).unfocus();
                final email = _emailController.text.trim();
                if (email.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email tidak boleh kosong')),
                  );
                  return;
                }
                final result = await AuthService().resetPassword(email);
                if (!context.mounted) return;
                Navigator.pop(context);
                if (result == "success") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email verifikasi telah dikirim!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
                }
              },
              child: const Text('Kirim'),
            ),
          ],
        );
      },
    );
  }

  // ================= LOGIN =================
  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan kata sandi tidak boleh kosong.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    String result = await AuthService().login(email, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result != 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result),
          backgroundColor: AppColors.error,
        ),
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
        (route) => false,
      );
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: SafeArea(
                          bottom: false,
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 20.h, bottom: 20.h),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.asset('assets/logo 3.png', width: 90.w, height: 90.w),
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      'BACA KAPAN SAJA, DI MANA SAJA',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: Colors.white70,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Material(
                                  color: const Color(0xFFF2F1ED),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(50),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: 24.w,
                                      right: 24.w,
                                      top: 24.h,
                                      bottom: 16.h + MediaQuery.of(context).padding.bottom,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Selamat Datang',
                                          style: TextStyle(
                                            fontSize: 24.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 16.h),
                                        // GOOGLE LOGIN
                                        buildGoogleButton(
                                          onTap: _isLoading ? () {} : () async {
                                            FocusScope.of(context).unfocus();
                                            setState(() => _isLoading = true);
                                            String result = await AuthService().signInWithGoogle();
                                            if (!context.mounted) return;
                                            setState(() => _isLoading = false);
                                            // AuthGate otomatis mendeteksi login & berpindah halaman dengan fade
                                            if (result != 'success' && result != 'Login dibatalkan') {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Login gagal: $result'),
                                                  backgroundColor: AppColors.error,
                                                ),
                                              );
                                            } else if (result == 'success') {
                                              // Hapus semua tumpukan halaman login/register dan kembali ke root (AuthGate)
                                              Navigator.pushAndRemoveUntil(
                                                context,
                                                PageRouteBuilder(
                                                  pageBuilder: (context, animation, secondaryAnimation) => const AuthGate(),
                                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                    return FadeTransition(opacity: animation, child: child);
                                                  },
                                                  transitionDuration: const Duration(milliseconds: 600),
                                                ),
                                                (route) => false,
                                              );
                                            }
                                          },
                                        ),
                                        SizedBox(height: 16.h),
                                        buildDivider('atau lanjutkan dengan email'),
                                        SizedBox(height: 16.h),
                                        // EMAIL
                                        buildInputField(
                                          label: 'Email',
                                          hint: "email@litera.com",
                                          controller: _emailController,
                                          keyboardType: TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                        ),
                                        // PASSWORD
                                        buildInputField(
                                          label: 'Kata Sandi',
                                          hint: "********",
                                          isPassword: true,
                                          controller: _passwordController,
                                          textInputAction: TextInputAction.done,
                                          isObscured: _isObscured,
                                          onFieldSubmitted: (_) {
                                            if (!_isLoading) _handleLogin();
                                          },
                                          onToggleVisibility: () {
                                            setState(() => _isObscured = !_isObscured);
                                          },
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: buildClickableText(
                                            text: 'Lupa Kata Sandi?',
                                            onTap: _showResetDialog,
                                          ),
                                        ),
                                        SizedBox(height: 16.h),
                                        ElevatedButton(
                                          onPressed: _isLoading ? null : _handleLogin,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            minimumSize: Size(double.infinity, 55.h),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(15.r),
                                            ),
                                          ),
                                          child: Text(
                                            'Masuk',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 16.h),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text("Belum punya akun? "),
                                            buildClickableText(
                                              text: 'Daftar Sekarang',
                                              onTap: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => const RegisterPage(),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Loading overlay
              if (_isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
