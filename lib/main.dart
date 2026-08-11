import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:litera2/core/bahasa/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:litera2/core/konstan/konstan_aplikasi.dart';
import 'package:litera2/core/konstan/warna_aplikasi.dart';
import 'package:litera2/fitur/auth/halaman/halaman_login.dart';
import 'package:litera2/fitur/profil/controller/controller_profil.dart';
import 'package:litera2/global/provider/provider_navigasi.dart';
import 'package:litera2/core/tema/tema_aplikasi.dart';
import 'package:litera2/global/widget/halaman_utama.dart';
import 'package:litera2/fitur/auth/halaman/halaman_onboarding.dart';
import 'package:litera2/fitur/buku/provider/provider_buku.dart';
import 'package:litera2/global/provider/provider_bahasa.dart';
import 'package:litera2/global/provider/provider_tema.dart';
import 'package:litera2/fitur/buku/provider/provider_bookmark.dart';
import 'package:litera2/fitur/buku/provider/provider_riwayat.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock app orientation to portrait globally
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  await Firebase.initializeApp();
  await Supabase.initialize(url: 'https://lhakcofpljwbtoydeaqv.supabase.co', publishableKey: 'sb_publishable_FugIQ4eqfXyXroYgBPnhuQ_gt9v4SCu');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ProfileController()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => BookmarkProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: const LiteraApp(),
    ),
  );
}

class LiteraApp extends StatelessWidget {
  const LiteraApp({super.key});

  static final _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: const FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
    },
  );

  static final ThemeData _lightTheme = AppTheme.light.copyWith(
    pageTransitionsTheme: _pageTransitionsTheme,
  );

  static final ThemeData _darkTheme = AppTheme.dark.copyWith(
    pageTransitionsTheme: _pageTransitionsTheme,
  );

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();

    return ScreenUtilInit(
      designSize: const Size(390, 844), // iPhone 13/14 size standard
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Litera',
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: themeProvider.mode,
          locale: languageProvider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // MaterialApp sudah menangani perubahan ThemeMode. Hindari animasi
          // tema global karena menganimasi dan me-rebuild seluruh pohon widget.
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _onboardingSeen;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(AppConstants.prefOnboardingSeen) ?? false;
    if (mounted) setState(() => _onboardingSeen = seen);
  }

  @override
  Widget build(BuildContext context) {
    // Masih loading preferensi
    if (_onboardingSeen == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final Widget child;

        if (snapshot.connectionState == ConnectionState.waiting) {
          child = const Scaffold(
            key: ValueKey('loading'),
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData) {
          // Gunakan wrapper untuk mencegat proses render MainPage
          // dan menampilkan loading sampai pengecekan admin selesai.
          child = AdminCheckWrapper(
            key: ValueKey(snapshot.data!.uid),
            user: snapshot.data!,
            child: const MainPage(key: ValueKey('main')),
          );
        } else {
          // User tidak login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.read<BookmarkProvider>().stopListening();
            context.read<HistoryProvider>().stopListening();
          });

          // Onboarding hanya tampil di install pertama
          if (!_onboardingSeen!) {
            child = const OnboardingPage(key: ValueKey('onboarding'));
          } else {
            child = const LoginPage(key: ValueKey('login'));
          }
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: child,
        );
      },
    );
  }
}

class AdminCheckWrapper extends StatefulWidget {
  final User user;
  final Widget child;

  const AdminCheckWrapper({
    super.key,
    required this.user,
    required this.child,
  });

  @override
  State<AdminCheckWrapper> createState() => _AdminCheckWrapperState();
}

class _AdminCheckWrapperState extends State<AdminCheckWrapper> {
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    bool isAdmin = false;

    // Lapis 1: cek custom claims di ID token
    try {
      final tokenResult = await widget.user.getIdTokenResult(true);
      if (tokenResult.claims?['role'] == 'admin') isAdmin = true;
    } catch (_) {}

    // Lapis 2: cek field role di Firestore sebagai fallback
    if (!isAdmin) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .get();
        if (doc.exists && doc.data()?['role'] == 'admin') isAdmin = true;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
        _isLoading = false;
      });
    }

    if (isAdmin) {
      // Tampilkan pesan error sebelum logout
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Akses ditolak. Akun Anda tidak memiliki izin untuk masuk ke aplikasi ini.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      // Jika tidak diizinkan, paksa logout. StreamBuilder di AuthGate akan 
      // merespons dan me-render halaman login.
      await FirebaseAuth.instance.signOut();
    } else {
      // Jika bukan admin, jalankan listener provider yang diperlukan MainPage
      if (mounted) {
        context.read<BookmarkProvider>().startListening();
        context.read<HistoryProvider>().startListening();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan loading screen saat sedang mencek, 
    // ATAU jika dia admin (karena sedang proses sign out).
    if (_isLoading || _isAdmin) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Jika aman (bukan admin & loading selesai), tampilkan MainPage.
    return widget.child;
  }
}
