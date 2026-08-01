import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:litera2/core/bahasa/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:litera2/core/konstan/konstan_aplikasi.dart';
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
          // User sudah login
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!context.mounted) return;
            context.read<BookmarkProvider>().startListening();
            context.read<HistoryProvider>().startListening();
          });
          child = const MainPage(key: ValueKey('main'));
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
