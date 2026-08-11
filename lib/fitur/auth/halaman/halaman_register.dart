import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:litera2/core/konstan/warna_aplikasi.dart';
import 'package:litera2/core/tema/tema_aplikasi.dart';
import 'package:litera2/global/widget/elemen_custom.dart';
import 'package:litera2/fitur/auth/service/service_auth.dart';
import 'package:litera2/main.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isAgreed = false;
  bool _isLoading = false;
  bool _isPasswordObscured = true;
  bool _isConfirmObscured = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ================= VALIDATION =================
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nama tidak boleh kosong';
    if (value.trim().length < 3) return 'Nama minimal 3 karakter';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email tidak boleh kosong';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) return 'Format email tidak valid';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Kata sandi minimal 8 karakter';
    if (value.length < 8) return 'Kata sandi minimal 8 karakter';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Konfirmasi kata sandi tidak cocok';
    if (value != _passwordController.text) return 'Konfirmasi kata sandi tidak cocok';
    return null;
  }

  // ================= DIALOG =================
  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Syarat & Ketentuan'),
        content: const Text('Silakan baca dan setujui ketentuan kami sebelum melanjutkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
  }

  // ================= REGISTER =================
  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_isAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamu harus menyetujui ketentuan terlebih dahulu.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await AuthService().register(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      _nameController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == "success") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pendaftaran berhasil! Selamat datang di Litera.'))
      );
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    // Auth pages selalu light mode
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
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
                              const Text(
                                'Buat Akun',
                                style: TextStyle(
                                  fontSize: 28,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'Bergabung dengan Litera sekarang',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: Material(
                                  color: const Color(0xFFF2F1ED),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(50)),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(30, 24, 30, 16 + MediaQuery.of(context).padding.bottom),
                                    child: Form(
                                      key: _formKey,
                                      autovalidateMode: AutovalidateMode.onUserInteraction,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          buildInputField(
                                            label: 'Nama Lengkap',
                                            hint: "John Doe",
                                            controller: _nameController,
                                            validator: _validateName,
                                            textInputAction: TextInputAction.next,
                                            keyboardType: TextInputType.name,
                                          ),
                                          buildInputField(
                                            label: 'Email',
                                            hint: "email@litera.com",
                                            controller: _emailController,
                                            validator: _validateEmail,
                                            keyboardType: TextInputType.emailAddress,
                                            textInputAction: TextInputAction.next,
                                          ),
                                          buildInputField(
                                            label: 'Kata Sandi',
                                            hint: "Min. 8 karakter",
                                            isPassword: true,
                                            isObscured: _isPasswordObscured,
                                            controller: _passwordController,
                                            validator: _validatePassword,
                                            textInputAction: TextInputAction.next,
                                            onToggleVisibility: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                                          ),
                                          buildInputField(
                                            label: 'Konfirmasi Kata Sandi',
                                            hint: 'Konfirmasi Kata Sandi',
                                            isPassword: true,
                                            isObscured: _isConfirmObscured,
                                            controller: _confirmPasswordController,
                                            validator: _validateConfirmPassword,
                                            textInputAction: TextInputAction.done,
                                            onFieldSubmitted: (_) => _handleRegister(),
                                            onToggleVisibility: () => setState(() => _isConfirmObscured = !_isConfirmObscured),
                                          ),

                                          // Checkbox
                                          Row(
                                            children: [
                                              Checkbox(
                                                value: _isAgreed,
                                                activeColor: AppColors.primary,
                                                onChanged: (v) => setState(() => _isAgreed = v ?? false),
                                              ),
                                              Expanded(
                                                child: Text.rich(
                                                  TextSpan(
                                                    text: "Saya setuju dengan ",
                                                    children: [
                                                      TextSpan(
                                                        text: 'Syarat & Ketentuan',
                                                        style: const TextStyle(
                                                          color: AppColors.accent,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
                                                      ),
                                                    ],
                                                  ),
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton(
                                            onPressed: _isLoading ? null : _handleRegister,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              minimumSize: const Size(double.infinity, 54),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                            ),
                                            child: _isLoading
                                                ? const CircularProgressIndicator(color: Colors.white)
                                                : const Text(
                                                    'Daftar Sekarang',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 17,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(height: 12),
                                          buildDivider('ATAU'),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Text("Sudah punya akun? "),
                                              buildClickableText(
                                                text: 'Masuk',
                                                onTap: () => Navigator.pop(context),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
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
