import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:litera2/fitur/buku/model/model_buku.dart';
import 'package:litera2/fitur/buku/halaman/halaman_baca.dart';
import 'package:litera2/fitur/buku/service/service_riwayat.dart';

class BookService {
  /// Mendapatkan URL PDF yang akan di-stream saat pembaca dibuka.
  static String? getReadableLink(BookModel book) {
    if (book.pdfDownloadLink != null && book.pdfDownloadLink!.isNotEmpty) {
      return book.pdfDownloadLink;
    }
    return null;
  }

  /// Mengecek apakah buku bisa dibaca di dalam aplikasi
  static bool isReadable(BookModel book) {
    return getReadableLink(book) != null;
  }

  /// Menangani aksi baca buku
  static Future<void> openBook(BuildContext context, BookModel book) async {
    final pdfUrl = book.pdfDownloadLink;

    if (pdfUrl == null || pdfUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buku ini tidak memiliki format digital PDF yang valid.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    debugPrint('[BookService] 📖 Opening PDF reader: $pdfUrl');
    _navigateToNativeReader(context, book, remoteUrl: pdfUrl);
  }

  /// Helper untuk navigasi ke native reader
  static void _navigateToNativeReader(
    BuildContext context, 
    BookModel book, 
    {required String remoteUrl}
  ) {
    // Update history
    ReadingHistoryService.recordBookOpen(book);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookReaderPage(
          book: book,
          remoteUrl: remoteUrl,
        ),
      ),
    );
  }

  /// Membuka buku berdasarkan ID (untuk riwayat/bookmark)
  static Future<void> openBookById(BuildContext context, String bookId) async {
    // Tampilkan loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final snapshot = await FirebaseFirestore.instance.collection('books').doc(bookId).get();
      if (!snapshot.exists) throw StateError('Buku tidak ditemukan');
      final book = BookModel.fromFirestore(snapshot.data()!, snapshot.id);
      if (!context.mounted) return;
      Navigator.pop(context); // Tutup loading

      await openBook(context, book);
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: Buku tidak ditemukan')),
        );
      }
    }
  }


}
