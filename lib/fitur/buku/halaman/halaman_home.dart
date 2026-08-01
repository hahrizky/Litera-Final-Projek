import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:litera2/core/bahasa/app_localizations.dart';

import 'package:litera2/core/konstan/warna_aplikasi.dart';
import 'package:litera2/core/konstan/konstan_aplikasi.dart';
import 'package:litera2/fitur/buku/model/model_buku.dart';
import 'package:litera2/fitur/buku/model/model_riwayat.dart';
import 'package:litera2/fitur/buku/provider/provider_buku.dart';
import 'package:litera2/fitur/buku/provider/provider_riwayat.dart';
import 'package:litera2/fitur/profil/widget/avatar_profil.dart';
import 'package:litera2/fitur/buku/halaman/halaman_detail.dart';
import 'package:litera2/fitur/buku/service/service_buku.dart';
import 'package:litera2/fitur/buku/widget/cover_buku.dart';
import 'package:litera2/global/widget/footer_aplikasi.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<BookProvider>();
      prov.loadDashboard();
      prov.startTopRatedListener();
    });
  }

  String _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h < 12) return l10n.greetingMorning;
    if (h < 15) return l10n.greetingAfternoon;
    if (h < 18) return l10n.greetingEvening;
    return l10n.greetingNight;
  }

  Map<String, String> _todayQuote(AppLocalizations l10n) {
    final isId = l10n.localeName == 'id';
    final idx = DateTime.now().dayOfYear % AppConstants.quotes.length;
    final q = AppConstants.quotes[idx];
    return {'text': isId ? q['id']! : q['en']!, 'author': q['author']!};
  }

  void _openDetail(BookModel book) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailBookPage(book: book)),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstName = (user?.displayName ?? 'Pembaca').split(' ').first;
    final quote = _todayQuote(l10n);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Status bar (jam, notif) tetap terlihat & tidak ketutupan warna header
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // ── Premium Header (Fixed/Tidak Bergerak) ───────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 16, 24, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [AppColors.navBackgroundDark, AppColors.backgroundDark]
                    : [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_greeting(l10n)}, $firstName 👋',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.greetingQuestion,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: const SmallProfileAvatar(radius: 26),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // ── Scrollable Content ─────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => context.read<BookProvider>().loadDashboard(force: true),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ── Continue Reading (Horizontal Cards) ──────────────────────
            SliverToBoxAdapter(
              child: Consumer<HistoryProvider>(
                builder: (_, readProv, _) {
                  final list = readProv.continueReading;
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(title: l10n.continueReading),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 140, // Optimized height
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _ContinueReadingCard(
                            history: list[i],
                            isDark: isDark,
                            l10n: l10n,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),
            ),

            // ── Reading Challenge ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Consumer<HistoryProvider>(
                builder: (_, readProv, _) {
                  final finished = readProv.finishedBooks.length;
                  const total = AppConstants.readingChallengeTarget;
                  final progress = (finished / total).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.readingChallenge,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.readingChallengeProgress(finished, total),
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 5,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

             // ── Top Rated Books ─────────────────────────────────
            SliverToBoxAdapter(
              child: Consumer<BookProvider>(
                builder: (_, prov, _) {
                  return _TopRatedSection(
                    books: prov.topRatedBooks,
                    state: prov.topRatedState,
                    onBookTap: _openDetail,
                    onRefresh: () => prov.startTopRatedListener(force: true),
                  );
                },
              ),
            ),


            // ── Quote of the Day ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.quoteOfTheDay.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.format_quote_rounded, color: AppColors.primary, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            quote['text']!,
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              height: 1.6,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '— ${quote['author']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: AppFooter()),
          ],
        ), // CustomScrollView
      ), // RefreshIndicator
      ), // Expanded
      ],
      ), // Column
      ), // Scaffold
    ); // AnnotatedRegion
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

extension on DateTime {
  int get dayOfYear {
    final start = DateTime(year, 1, 1);
    return difference(start).inDays;
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.w900, 
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _TopRatedSection ─────────────────────────────────────────────────────────

class _TopRatedSection extends StatelessWidget {
  final List<BookModel> books;
  final LoadState state;
  final void Function(BookModel) onBookTap;
  final VoidCallback onRefresh;

  const _TopRatedSection({
    required this.books,
    required this.state,
    required this.onBookTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text(
                'Rating Tertinggi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (state == LoadState.loading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state == LoadState.error)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          )
        else if (books.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star_border_rounded, color: AppColors.textMuted, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Belum ada rating',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Beri rating pada buku favoritmu agar muncul di sini.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: books.length,
            itemBuilder: (_, i) => _TopRatedItem(
              book: books[i],
              rank: i + 1,
              isDark: isDark,
              onTap: () => onBookTap(books[i]),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _TopRatedItem extends StatelessWidget {
  final BookModel book;
  final int rank;
  final bool isDark;
  final VoidCallback onTap;

  const _TopRatedItem({
    required this.book,
    required this.rank,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final medalColors = [Colors.amber, Colors.blueGrey.shade300, Colors.brown.shade300];
    final rankColor = isTop3 ? medalColors[rank - 1] : AppColors.textMuted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isTop3
                ? rankColor.withValues(alpha: 0.4)
                : AppColors.primary.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rank badge
            SizedBox(
              width: 36,
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: isTop3 ? 20 : 15,
                  fontWeight: FontWeight.w900,
                  color: rankColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            // Cover
            BookCoverWidget(
              imageUrl: book.thumbnail,
              width: 52,
              height: 72,
              borderRadius: 10,
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.authors.join(', '),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Rating badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    book.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  final ReadingHistoryModel history;
  final bool isDark;
  final AppLocalizations l10n;

  const _ContinueReadingCard({
    required this.history,
    required this.isDark,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16, bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => BookService.openBookById(context, history.bookId),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                BookCoverWidget(
                  imageUrl: history.thumbnail,
                  width: 75,
                  height: 110,
                  borderRadius: 16,
                  fallbackColor: AppColors.primary.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        history.title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        history.authors,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: history.progress.clamp(0.0, 1.0),
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.percentDone(history.progressPercent),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
