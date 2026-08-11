/// Konstanta global aplikasi: kunci preferensi, konfigurasi API, dan batas UI.
abstract final class AppConstants {
  // ── SharedPreferences keys ─────────────────────────────────────────────────
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefLocale = 'pref_locale';
  static const String prefLanguageSelected = 'pref_language_selected';
  static const String prefOnboardingSeen = 'pref_onboarding_seen';


  // ── Google Books API ───────────────────────────────────────────────────────
  /// Cara inject key saat build:
  /// flutter run --dart-define=GOOGLE_BOOKS_API_KEY=kunci_anda
  /// flutter build apk --dart-define=GOOGLE_BOOKS_API_KEY=kunci_anda
  static const String booksApiBase = 'https://www.googleapis.com/books/v1/volumes';
  static const String booksApiKey = String.fromEnvironment('GOOGLE_BOOKS_API_KEY', defaultValue: '');
  static const int booksDefaultMax = 20;
  static const int booksPageSize = 20;
  static const Duration booksTimeout = Duration(seconds: 20);
  static const Duration booksRetryDelay = Duration(seconds: 2);

  // ── Firestore collections ──────────────────────────────────────────────────
  static const String colUsers = 'users';
  static const String colBookmarks = 'bookmarks';
  static const String colReadingHistory = 'reading_history';
  static const String colRatings = 'ratings';

  // ── Tantangan membaca ──────────────────────────────────────────────────────
  static const int readingChallengeTarget = 12;

  // ── UI ─────────────────────────────────────────────────────────────────────
  static const double borderRadiusCard = 16.0;
  static const double borderRadiusLarge = 24.0;
  static const double pagePadding = 20.0;
  static const double sectionSpacing = 32.0;

  // ── Supported locales ──────────────────────────────────────────────────────
  static const String localeId = 'id';
  static const String localeEn = 'en';
  static const String defaultLocale = localeId;

  // ── Kutipan (ditampilkan di dashboard) ────────────────────────────────────
  static const List<Map<String, String>> quotes = [
    {
      'id': '"Buku adalah cermin; kamu hanya melihat di dalamnya apa yang sudah ada dalam dirimu."',
      'en': '"A book is a mirror; you only see in it what is already inside you."',
      'author': 'Carlos Ruiz Zafón',
    },
    {
      'id': '"Buku adalah sihir portabel yang unik."',
      'en': '"Books are a uniquely portable magic."',
      'author': 'Stephen King',
    },
    {
      'id': '"Membaca adalah meminjam."',
      'en': '"To read is to borrow."',
      'author': 'Arthur Schopenhauer',
    },
    {
      'id': '"Ruangan tanpa buku ibarat tubuh tanpa jiwa."',
      'en': '"A room without books is like a body without a soul."',
      'author': 'Marcus Tullius Cicero',
    },
  ];
}
