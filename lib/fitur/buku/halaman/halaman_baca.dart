import 'dart:async';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:litera2/core/konstan/warna_aplikasi.dart';
import 'package:litera2/fitur/buku/model/model_buku.dart';
import 'package:litera2/fitur/buku/service/service_bookmark.dart';
import 'package:litera2/fitur/buku/service/service_riwayat.dart';

/// Pembaca PDF streaming. File tidak diunduh atau disimpan ke cache aplikasi.
class BookReaderPage extends StatefulWidget {
  const BookReaderPage({super.key, required this.book, required this.remoteUrl});
  final BookModel book;
  final String remoteUrl;

  @override
  State<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<BookReaderPage> {
  final _viewerKey = GlobalKey<SfPdfViewerState>();
  final _controller = PdfViewerController();
  int _progress = 0;
  Timer? _progressSaveTimer;
  double? _pendingProgress;
  int? _pendingPage;

  @override
  void dispose() {
    _progressSaveTimer?.cancel();
    _savePendingProgress();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleProgressSave({required double progress, required int page}) {
    _pendingProgress = progress;
    _pendingPage = page;
    _progressSaveTimer?.cancel();
    _progressSaveTimer = Timer(const Duration(seconds: 10), _savePendingProgress);
  }

  void _savePendingProgress() {
    final progress = _pendingProgress;
    final page = _pendingPage;
    if (progress == null || page == null) return;

    _pendingProgress = null;
    _pendingPage = null;
    ReadingHistoryService.updateProgress(
      widget.book.id,
      progress: progress,
      lastPage: page,
    );
  }

  Future<void> _restoreProgress() async {
    final history = await ReadingHistoryService.getBookHistory(widget.book.id);
    if (history != null && history.lastPage > 1) _controller.jumpToPage(history.lastPage);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: Text(_progress == 0 ? widget.book.title : '${widget.book.title} ($_progress%)', overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(onPressed: () => _viewerKey.currentState?.openBookmarkView(), icon: const Icon(Icons.toc_rounded)),
            StreamBuilder<bool>(
              stream: BookmarkService.watchIsBookmarked(widget.book.id),
              builder: (_, snapshot) => IconButton(
                icon: Icon(snapshot.data == true ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () => BookmarkService.toggleBookmark(widget.book),
              ),
            ),
          ],
        ),
        body: SfPdfViewer.network(
          widget.remoteUrl,
          key: _viewerKey,
          controller: _controller,
          canShowScrollHead: true,
          onDocumentLoaded: (_) => _restoreProgress(),
          onPageChanged: (details) {
            final total = _controller.pageCount;
            if (total <= 0) return;
            final progress = details.newPageNumber / total;
            _scheduleProgressSave(progress: progress, page: details.newPageNumber);
            final percentage = (progress * 100).round();
            if (percentage != _progress) {
              setState(() => _progress = percentage);
            }
          },
        ),
      );
}
