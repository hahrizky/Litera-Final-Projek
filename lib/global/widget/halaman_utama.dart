import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:litera2/core/bahasa/app_localizations.dart';

import 'package:litera2/core/konstan/warna_aplikasi.dart';
import 'package:litera2/global/provider/provider_navigasi.dart';
import 'package:litera2/fitur/profil/widget/avatar_profil.dart';
import 'package:litera2/fitur/profil/service/service_user.dart';
import 'package:litera2/fitur/buku/halaman/halaman_home.dart';
import 'package:litera2/fitur/buku/halaman/halaman_explore.dart';
import 'package:litera2/fitur/buku/halaman/halaman_library.dart';
import 'package:litera2/fitur/profil/halaman/halaman_profil.dart';
import 'package:litera2/fitur/admin/halaman/halaman_admin_dashboard.dart';
import 'package:litera2/fitur/admin/halaman/halaman_manajemen_buku.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final Set<int> _visitedTabs = {0};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder(
      stream: UserService.watchProfile(),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data?.isAdmin == true;

        final pages = isAdmin
            ? const [
                AdminDashboardPage(),
                BookManagementPage(),
                ProfilePage(),
              ]
            : const [
                HomePage(),
                ExplorePage(),
                LibraryPage(),
                ProfilePage(),
              ];

        return Consumer<NavigationProvider>(
          builder: (context, nav, _) {
            final currentIndex = nav.selectedIndex >= pages.length ? 0 : nav.selectedIndex;
            _visitedTabs.add(currentIndex);

            return Scaffold(
              // extendBody dihapus - Scaffold sekarang mengelola safe area secara otomatis
              body: IndexedStack(
                index: currentIndex,
                // Tab hanya dibuat setelah pertama kali dibuka. Tab yang sudah
                // pernah dikunjungi tetap dipertahankan agar scroll/state tidak hilang.
                children: List.generate(
                  pages.length,
                  (index) => _visitedTabs.contains(index)
                      ? pages[index]
                      : const SizedBox.shrink(),
                ),
              ),
              bottomNavigationBar: isAdmin
                  ? _buildAdminNavBar(context, nav, currentIndex)
                  : _buildNavBar(context, nav, currentIndex, l10n, isDark, cs),
            );
          },
        );
      },
    );
  }

  // ── Navbar Admin ──────────────────────────────────────────────────────────
  Widget _buildAdminNavBar(BuildContext context, NavigationProvider nav, int currentIndex) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: nav.setIndex,
      backgroundColor: const Color(0xFF1E293B),
      indicatorColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined, color: Color(0xFF94A3B8)),
          selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFF38BDF8)),
          label: 'Command',
        ),
        const NavigationDestination(
          icon: Icon(Icons.library_books_outlined, color: Color(0xFF94A3B8)),
          selectedIcon: Icon(Icons.library_books_rounded, color: Color(0xFF38BDF8)),
          label: 'Library',
        ),
        NavigationDestination(
          icon: const Padding(
            padding: EdgeInsets.all(2),
            child: SmallProfileAvatar(radius: 11),
          ),
          selectedIcon: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
            ),
            child: const SmallProfileAvatar(radius: 11),
          ),
          label: 'Profile',
        ),
      ],
    );
  }

  // ── Navbar User (seperti WhatsApp) ────────────────────────────────────────
  Widget _buildNavBar(
    BuildContext context,
    NavigationProvider nav,
    int currentIndex,
    AppLocalizations l10n,
    bool isDark,
    ColorScheme cs,
  ) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: nav.setIndex,
      // Scaffold akan otomatis menambah safe area di bawah navbar
      backgroundColor: isDark ? AppColors.navBackgroundDark : AppColors.navBackground,
      indicatorColor: AppColors.primary.withValues(alpha: 0.15),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: l10n.dashboardTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.explore_outlined),
          selectedIcon: const Icon(Icons.explore_rounded),
          label: l10n.exploreTitle,
        ),
        NavigationDestination(
          icon: const Icon(Icons.bookmark_outline_rounded),
          selectedIcon: const Icon(Icons.bookmark_rounded),
          label: l10n.myCollection,
        ),
        NavigationDestination(
          icon: Padding(
            padding: const EdgeInsets.all(2),
            child: SmallProfileAvatar(radius: 11.r),
          ),
          selectedIcon: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: SmallProfileAvatar(radius: 11.r),
          ),
          label: l10n.profileTitle,
        ),
      ],
    );
  }
}
