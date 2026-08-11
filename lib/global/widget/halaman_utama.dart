import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:litera2/core/bahasa/app_localizations.dart';

import 'package:litera2/core/konstan/warna_aplikasi.dart';
import 'package:litera2/global/provider/provider_navigasi.dart';
import 'package:litera2/fitur/profil/widget/avatar_profil.dart';
import 'package:litera2/fitur/buku/halaman/halaman_home.dart';
import 'package:litera2/fitur/buku/halaman/halaman_explore.dart';
import 'package:litera2/fitur/buku/halaman/halaman_library.dart';
import 'package:litera2/fitur/profil/halaman/halaman_profil.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final Set<int> _visitedTabs = {0};

  static const List<Widget> _pages = [
    HomePage(),
    ExplorePage(),
    LibraryPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Consumer<NavigationProvider>(
      builder: (context, nav, _) {
        final currentIndex = nav.selectedIndex >= _pages.length ? 0 : nav.selectedIndex;
        _visitedTabs.add(currentIndex);

        return Scaffold(
          body: IndexedStack(
            index: currentIndex,
            // Tab hanya dibuat setelah pertama kali dibuka. Tab yang sudah
            // pernah dikunjungi tetap dipertahankan agar scroll/state tidak hilang.
            children: List.generate(
              _pages.length,
              (index) => _visitedTabs.contains(index)
                  ? _pages[index]
                  : const SizedBox.shrink(),
            ),
          ),
          bottomNavigationBar: _buildNavBar(context, nav, currentIndex, l10n, isDark, cs),
        );
      },
    );
  }

  // ── Navbar User ───────────────────────────────────────────────────────────
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
