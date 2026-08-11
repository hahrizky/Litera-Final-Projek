import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:litera2/core/bahasa/app_localizations.dart';

import 'package:litera2/core/konstan/warna_aplikasi.dart';
import 'package:litera2/fitur/buku/model/model_buku.dart';
import 'package:litera2/fitur/buku/provider/provider_bookmark.dart';
import 'package:litera2/fitur/buku/provider/provider_riwayat.dart';
import 'package:litera2/fitur/buku/provider/provider_rating.dart';
import 'package:litera2/global/service/service_firestore.dart';
import 'package:litera2/fitur/buku/widget/cover_buku.dart';
import 'package:litera2/fitur/buku/widget/bar_rating.dart';
import 'package:litera2/fitur/buku/widget/kartu_review.dart';
import 'package:litera2/fitur/buku/service/service_buku.dart';

class DetailBookPage extends StatefulWidget {
  final BookModel book;

  const DetailBookPage({super.key, required this.book});

  @override
  State<DetailBookPage> createState() => _DetailBookPageState();
}

class _DetailBookPageState extends State<DetailBookPage> {
  bool _descExpanded = false;
  final TextEditingController _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure book document exists for global ratings
      FirestoreService.ensureBookExists(
        bookId: widget.book.id,
        title: widget.book.title,
        thumbnail: widget.book.bestCover ?? '',
        category: widget.book.categoryDisplay,
      );
    });
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _openReader(BuildContext context) async {
    final book = widget.book;
    BookService.openBook(context, book);
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChangeNotifierProvider(
      create: (_) => RatingProvider(bookId: book.id),
      child: Scaffold(
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Premium App Bar ─────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 380,
              pinned: true,
              stretch: true,
              backgroundColor: isDark ? AppColors.backgroundDark : AppColors.primaryDark,
              foregroundColor: Colors.white,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    BookCoverWidget(
                      imageUrl: book.bestCover,
                      width: double.infinity,
                      height: 380,
                      borderRadius: 0,
                      fallbackColor: AppColors.primary,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent, 
                            isDark ? AppColors.backgroundDark.withValues(alpha: 0.8) : AppColors.primaryDark.withValues(alpha: 0.8), 
                            isDark ? AppColors.backgroundDark : AppColors.primaryDark
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 30,
                      left: 24,
                      right: 24,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Header gambar cover dengan efek melayang (floating).
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: BookCoverWidget(
                              imageUrl: book.bestCover,
                              width: 120,
                              height: 180,
                              borderRadius: 20,
                              fallbackColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  book.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  book.authorsDisplay,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                Consumer<RatingProvider>(
                                  builder: (_, ratingProv, _) => StarDisplay(
                                    rating: ratingProv.average,
                                    count: ratingProv.totalRatings,
                                    starSize: 16,
                                    textColor: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Consumer<BookmarkProvider>(
                  builder: (context, bookmarkProv, _) {
                    final isBookmarked = bookmarkProv.isBookmarked(book.id);
                    return IconButton(
                      onPressed: () async {
                        await bookmarkProv.toggleBookmark(book);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isBookmarked ? l10n.bookmarkRemoved : l10n.bookmarked),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                        child: Icon(
                          isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                          color: isBookmarked ? AppColors.accent : Colors.white,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),

            // ── Konten Utama ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status progres membaca dan tombol untuk melanjutkan.
                    Consumer<HistoryProvider>(
                      builder: (context, readProv, _) {
                        final progress = readProv.progressOf(book.id);
                        final hasHistory = readProv.hasHistory(book.id);
                        return _ReadSection(
                          book: book,
                          progress: progress,
                          hasHistory: hasHistory,
                          onRead: () => _openReader(context),
                          l10n: l10n,
                        );
                      },
                    ),

                    const SizedBox(height: 40),
                    _InfoGrid(book: book, isDark: isDark, l10n: l10n),
                    const SizedBox(height: 40),

                    // Deskripsi buku dengan fungsi ekspansi (baca selengkapnya).
                    if (book.description.isNotEmpty) ...[
                      _SectionHeader(title: l10n.aboutBook),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final style = const TextStyle(fontSize: 15, height: 1.7, color: AppColors.textSecondary, fontWeight: FontWeight.w500);
                          final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
                          final span = TextSpan(text: book.description, style: effectiveStyle);
                          final tp = TextPainter(
                            text: span,
                            maxLines: 5,
                            textDirection: Directionality.of(context),
                            textScaler: MediaQuery.textScalerOf(context),
                          );
                          tp.layout(maxWidth: constraints.maxWidth);
                          final isOverflowing = tp.didExceedMaxLines;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedCrossFade(
                                duration: const Duration(milliseconds: 300),
                                crossFadeState: _descExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                firstChild: Text(
                                  book.description,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: style,
                                ),
                                secondChild: Text(
                                  book.description,
                                  style: style,
                                ),
                              ),
                              if (isOverflowing)
                                TextButton(
                                  onPressed: () => setState(() => _descExpanded = !_descExpanded),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: EdgeInsets.zero),
                                  child: Text(_descExpanded ? l10n.showLess : l10n.readMore, style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Panel ringkasan rating dan agregasi ulasan.
                    Consumer<RatingProvider>(
                      builder: (context, ratingProv, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(title: 'Ulasan & Rating'),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Text(
                                ratingProv.average.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, height: 1.0),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StarDisplay(rating: ratingProv.average, starSize: 18),
                                  const SizedBox(height: 8),
                                  Text(
                                    ' rating',
                                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _RatingSubmission(
                      bookId: book.id,
                      l10n: l10n,
                      controller: _reviewController,
                    ),
                    const SizedBox(height: 24),
                    _ReviewList(l10n: l10n),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Ruang kosong tambahan di bawah agar tidak menabrak batas layar ponsel.
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Komponen Pembantu (Helpers) ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
    );
  }
}

class _ReadSection extends StatelessWidget {
  final BookModel book;
  final double progress;
  final bool hasHistory;
  final VoidCallback onRead;
  final AppLocalizations l10n;

  const _ReadSection({
    required this.book,
    required this.progress,
    required this.hasHistory,
    required this.onRead,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasHistory && progress > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.percentDone((progress * 100).toInt()),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
        ],
        if (BookService.isReadable(book) || book.hasPreview || book.hasWebReader)
          FilledButton.icon(
            onPressed: onRead,
            icon: const Icon(Icons.auto_stories_rounded),
            label: Text(hasHistory && progress > 0 ? l10n.continueReadingBtn : l10n.startReading),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.lock_clock_rounded),
            label: Text(l10n.previewUnavailable),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
      ],
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final BookModel book;
  final bool isDark;
  final AppLocalizations l10n;
  const _InfoGrid({required this.book, required this.isDark, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.cardDark : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _InfoItem(icon: Icons.calendar_month_rounded, label: l10n.infoYear, value: book.year.isEmpty ? '—' : book.year),
          _divider(),
          _InfoItem(icon: Icons.menu_book_rounded, label: l10n.infoPages, value: book.pageCount > 0 ? '${book.pageCount}' : '—'),
          _divider(),
          _InfoItem(icon: Icons.language_rounded, label: l10n.infoLanguage, value: book.language.toUpperCase()),
          _divider(),
          _InfoItem(icon: Icons.category_rounded, label: l10n.infoGenre, value: book.categoryDisplay),
        ],
      ),
    );
  }

  Widget _divider() => Container(height: 35, width: 1.5, color: AppColors.primary.withValues(alpha: 0.1));
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _RatingSubmission extends StatefulWidget {
  final String bookId;
  final AppLocalizations l10n;
  final TextEditingController controller;

  const _RatingSubmission({
    required this.bookId,
    required this.l10n,
    required this.controller,
  });

  @override
  State<_RatingSubmission> createState() => _RatingSubmissionState();
}

class _RatingSubmissionState extends State<_RatingSubmission> {
  double _rating = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            const Icon(Icons.lock_person_rounded, color: AppColors.primary, size: 40),
            const SizedBox(height: 16),
            Text(
              widget.l10n.loginToRate,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    final prov = context.watch<RatingProvider>();

    // Isi form secara otomatis jika pengguna sebelumnya sudah pernah memberi ulasan.
    if (_rating == 0 && prov.hasMyReview) {
      _rating = prov.myReview!.rating;
      widget.controller.text = prov.myReview!.review;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(widget.l10n.yourRating, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 16),
          RatingBarWidget(
            initialRating: _rating,
            itemSize: 36,
            onRatingChanged: (r) {
              setState(() => _rating = r);
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: widget.controller,
            maxLines: 3,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: widget.l10n.writeReview,
              hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAF9),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _rating == 0 || prov.isSubmitting
                  ? null
                  : () async {
                      final success = await prov.submit(rating: _rating, review: widget.controller.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? widget.l10n.ratingSuccess : (prov.error ?? widget.l10n.ratingError)),
                            backgroundColor: success ? AppColors.success : AppColors.error,
                          ),
                        );
                      }
                    },
              child: prov.isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : Text(prov.hasMyReview ? widget.l10n.updateRating : widget.l10n.submitRating),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewList extends StatelessWidget {
  final AppLocalizations l10n;
  const _ReviewList({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<RatingProvider>();
    if (prov.isLoading && prov.reviews.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    if (prov.reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(Icons.rate_review_outlined, color: AppColors.textMuted, size: 48),
              const SizedBox(height: 12),
              Text(l10n.noReviews, style: const TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: prov.reviews.map((r) => ReviewCard(review: r)).toList(),
    );
  }
}
