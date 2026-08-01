import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:litera2/main.dart';

import 'package:litera2/core/konstan/warna_aplikasi.dart';
import 'package:litera2/core/konstan/konstan_aplikasi.dart';
import 'package:litera2/fitur/auth/halaman/halaman_login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 30.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset('assets/logo 3.png', width: 140.w, height: 140.w),
            ),
            SizedBox(height: 24.h),
            Text(
              'BACA. JELAJAH. BERKEMBANG.',
              style: TextStyle(color: Colors.white60, letterSpacing: 2.w, fontSize: 10.sp),
            ),
            SizedBox(height: 50.h),
            Text(
              'Ratusan buku di\ngenggamanmu',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26.sp,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 15.h),
            Text(
              'Mulai perjalanan membaca hari ini.\nTemukan buku yang tepat untukmu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14.sp),
            ),
            const Spacer(),
           ElevatedButton(
              onPressed: () async {
                // Tandai onboarding sudah dilihat agar tidak muncul lagi
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(AppConstants.prefOnboardingSeen, true);

                if (!context.mounted) return;
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthGate()),
                    (route) => false,
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: Size(double.infinity, 55.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.r),
                ),
              ),
              child: Text(
                'Mulai Sekarang',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
            ),
            SizedBox(height: 25.h),
          ],
        ),
      ),
      ),
    );
  }
}
