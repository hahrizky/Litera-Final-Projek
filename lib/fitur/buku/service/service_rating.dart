import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:litera2/core/konstan/konstan_aplikasi.dart';
import 'package:litera2/fitur/buku/model/model_review.dart';
import 'package:litera2/global/service/service_firestore.dart';


/// Mengelola seluruh operasi Firestore untuk sistem rating dan ulasan buku.
/// Setiap perubahan rating dieksekusi di dalam transaksi atomik untuk
/// menjamin konsistensi data agregat pada dokumen buku.
///
/// Jalur koleksi: books/{bookId}/ratings/{userId}
class RatingService {
  static final _firestore = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> _ratingsCol(String bookId) =>
      _firestore
          .collection('books')
          .doc(bookId)
          .collection(AppConstants.colRatings);

  // ── Stream Realtime ─────────────────────────────────────────────────────────

  /// Memantau seluruh ulasan sebuah buku secara realtime, diurutkan dari terbaru.
  /// Gunakan stream ini pada halaman detail buku agar daftar ulasan selalu mutakhir.
  static Stream<List<ReviewModel>> watchReviews(String bookId) {
    return _ratingsCol(bookId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReviewModel.fromFirestore(
                  d.data(), 
                  d.id,
                ))
            .toList());
  }

  /// Memantau ulasan milik pengguna yang sedang aktif secara realtime.
  /// Mengembalikan `null` jika pengguna belum memberikan ulasan atau belum masuk.
  static Stream<ReviewModel?> watchMyReview(String bookId) {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _ratingsCol(bookId).doc(uid).snapshots().map((doc) =>
        doc.exists ? ReviewModel.fromFirestore(doc.data()!, doc.id) : null);
  }

  // ── Pengambilan Data (One-Shot) ──────────────────────────────────────────────

  /// Mengambil seluruh ulasan buku sekali tanpa berlangganan perubahan.
  /// Mendukung pengurutan berdasarkan nilai rating atau waktu pembuatan.
  static Future<List<ReviewModel>> getReviews(
    String bookId, {
    bool sortByRating = false,
  }) async {
    try {
      final query = sortByRating
          ? _ratingsCol(bookId).orderBy('rating', descending: true)
          : _ratingsCol(bookId).orderBy('createdAt', descending: true);
      final snap = await query.get();
      return snap.docs
          .map((d) => ReviewModel.fromFirestore(d.data(), d.id))
          .toList();
    } catch (e) {
      debugPrint('[RatingService] getStats error: $e');
      return [];
    }
  }

  /// Mengambil ulasan milik pengguna yang sedang aktif sekali tanpa berlangganan.
  /// Mengembalikan `null` jika pengguna belum memberikan ulasan.
  static Future<ReviewModel?> getMyReview(String bookId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc = await _ratingsCol(bookId).doc(uid).get();
      if (!doc.exists) return null;
      return ReviewModel.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('[RatingService] getMyReview error: $e');
      return null;
    }
  }

  /// Mengambil data agregat rating buku (rata-rata, jumlah penilai, jumlah ulasan)
  /// langsung dari dokumen buku, bukan dari subcollection ratings.
  /// Ini lebih efisien karena hanya membutuhkan satu pembacaan dokumen.
  static Future<({double average, int count, int reviews})> getStats(String bookId) async {
    try {
      final doc = await _firestore.collection('books').doc(bookId).get();
      if (!doc.exists) return (average: 0.0, count: 0, reviews: 0);
      final data = doc.data()!;
      return (
        average: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
        count: (data['ratingsCount'] as int? ?? data['totalRatings'] as int?) ?? 0,
        reviews: (data['totalReviews'] as int?) ?? 0
      );
    } catch (e) {
      debugPrint('[RatingService] getStats error: $e');
      return (average: 0.0, count: 0, reviews: 0);
    }
  }

  // ── Penulisan Data ──────────────────────────────────────────────────────────

  /// Mengirim atau memperbarui rating dari pengguna yang sedang aktif.
  ///
  /// Seluruh operasi dijalankan dalam satu transaksi Firestore agar atomik:
  /// data rating pengguna dan statistik agregat buku diperbarui secara bersamaan
  /// atau tidak sama sekali — mencegah ketidakkonsistenan data.
  static Future<void> submitRating({
    required String bookId,
    required double rating,
    required String review,
  }) async {
    debugPrint('[RatingService] 🚀 Starting atomic submitRating for bookId: $bookId');
    
    // Validasi nilai rating sebelum menyentuh database.
    // Rating di luar rentang 1–5 akan merusak kalkulasi statistik buku.
    if (rating < 1 || rating > 5) {
      debugPrint('[RatingService] ❌ Nilai rating tidak valid: $rating (harus 1–5)');
      throw ArgumentError('Rating harus berada di antara 1 dan 5. Nilai yang diterima: $rating');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[RatingService] ❌ Error: No user logged in');
      throw Exception('User must be logged in to rate.');
    }

    final uid = user.uid;
    final ratingDocRef = _ratingsCol(bookId).doc(uid);
    final bookDocRef = _firestore.collection('books').doc(bookId);

    try {
      await _firestore.runTransaction((transaction) async {
        debugPrint('[RatingService] 🔄 Transaksi dimulai untuk UID: $uid');

        // Baca dokumen rating pengguna dan dokumen buku secara bersamaan
        // di dalam transaksi agar data yang dibaca selalu konsisten.
        final ratingDocSnap = await transaction.get(ratingDocRef);
        final bookDocSnap = await transaction.get(bookDocRef);
        
        // Tentukan apakah ini ulasan baru atau pembaruan ulasan yang sudah ada.
        final bool isNewReview = !ratingDocSnap.exists;
        final double oldRating = isNewReview ? 0.0 : (ratingDocSnap.data()?['rating'] as num?)?.toDouble() ?? 0.0;
        final String oldReview = isNewReview ? '' : (ratingDocSnap.data()?['review'] as String? ?? '');

        // Deteksi perubahan status teks ulasan untuk memperbarui counter ulasan.
        final bool isAddingReviewText = review.trim().isNotEmpty && oldReview.trim().isEmpty;
        final bool isRemovingReviewText = review.trim().isEmpty && oldReview.trim().isNotEmpty;

        final ratingData = {
          'userId': uid,
          'userName': user.displayName ?? 'Pengguna',
          'userPhoto': user.photoURL,
          'bookId': bookId,
          'rating': rating,
          'review': review,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (isNewReview) {
          ratingData['createdAt'] = FieldValue.serverTimestamp();
          transaction.set(ratingDocRef, ratingData);
        } else {
          transaction.update(ratingDocRef, ratingData);
        }

        // -- Perbarui Statistik Agregat Dokumen Buku --
        final Map<String, dynamic> bookUpdate = {
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (!bookDocSnap.exists) {
          // Dokumen buku belum memiliki data statistik; inisialisasi dari awal.
          bookUpdate['ratingsCount'] = 1;
          bookUpdate['totalRatingSum'] = rating;
          bookUpdate['averageRating'] = rating;
          bookUpdate['totalReviews'] = review.trim().isNotEmpty ? 1 : 0;
          
          bookUpdate['star1'] = rating == 1 ? 1 : 0;
          bookUpdate['star2'] = rating == 2 ? 1 : 0;
          bookUpdate['star3'] = rating == 3 ? 1 : 0;
          bookUpdate['star4'] = rating == 4 ? 1 : 0;
          bookUpdate['star5'] = rating == 5 ? 1 : 0;
          
          transaction.set(bookDocRef, bookUpdate, SetOptions(merge: true));
        } else {
          final bookData = bookDocSnap.data()!;
          int ratingsCount = (bookData['ratingsCount'] as int? ?? bookData['totalRatings'] as int? ?? 0);
          double totalRatingSum = (bookData['totalRatingSum'] as num? ?? 0.0).toDouble();
          int totalReviews = (bookData['totalReviews'] as int? ?? 0);
          double currentAverage = (bookData['averageRating'] as num? ?? 0.0).toDouble();

          // Koreksi data lama yang tidak konsisten: total jumlah rating > 0
          // tetapi total nilai rating masih 0 akibat skema data versi sebelumnya.
          if (totalRatingSum == 0.0 && ratingsCount > 0) {
            if (currentAverage > 0) {
              // Rekonstruksi total nilai rating dari rata-rata yang tersimpan.
              totalRatingSum = currentAverage * ratingsCount;
            } else {
              // Data tidak dapat dipulihkan; reset counter ke kondisi awal.
              ratingsCount = 0;
            }
          }
          
          int star1 = bookData['star1'] as int? ?? 0;
          int star2 = bookData['star2'] as int? ?? 0;
          int star3 = bookData['star3'] as int? ?? 0;
          int star4 = bookData['star4'] as int? ?? 0;
          int star5 = bookData['star5'] as int? ?? 0;

          if (isNewReview) {
            // Tambahkan rating baru ke semua counter.
            ratingsCount += 1;
            totalRatingSum += rating;
            if (review.trim().isNotEmpty) totalReviews += 1;
            
            if (rating == 1) star1 += 1;
            if (rating == 2) star2 += 1;
            if (rating == 3) star3 += 1;
            if (rating == 4) star4 += 1;
            if (rating == 5) star5 += 1;
          } else {
            // Perbarui total nilai: kurangi rating lama, tambah rating baru.
            totalRatingSum = totalRatingSum - oldRating + rating;
            if (isAddingReviewText) totalReviews += 1;
            if (isRemovingReviewText) totalReviews -= 1;

            // Kurangi distribusi bintang untuk rating yang diganti.
            if (oldRating == 1) star1 = (star1 > 0) ? star1 - 1 : 0;
            if (oldRating == 2) star2 = (star2 > 0) ? star2 - 1 : 0;
            if (oldRating == 3) star3 = (star3 > 0) ? star3 - 1 : 0;
            if (oldRating == 4) star4 = (star4 > 0) ? star4 - 1 : 0;
            if (oldRating == 5) star5 = (star5 > 0) ? star5 - 1 : 0;

            // Tambah distribusi bintang untuk rating yang baru.
            if (rating == 1) star1 += 1;
            if (rating == 2) star2 += 1;
            if (rating == 3) star3 += 1;
            if (rating == 4) star4 += 1;
            if (rating == 5) star5 += 1;
          }

          // Hitung ulang rata-rata dari total nilai dan jumlah penilai.
          bookUpdate['ratingsCount'] = ratingsCount;
          bookUpdate['totalRatingSum'] = totalRatingSum;
          bookUpdate['averageRating'] = ratingsCount > 0 ? totalRatingSum / ratingsCount : 0.0;
          bookUpdate['totalReviews'] = totalReviews;
          
          bookUpdate['star1'] = star1;
          bookUpdate['star2'] = star2;
          bookUpdate['star3'] = star3;
          bookUpdate['star4'] = star4;
          bookUpdate['star5'] = star5;
          
          transaction.update(bookDocRef, bookUpdate);
        }
      });

      debugPrint('[RatingService] ✅ Transaction committed successfully');
    } catch (e, stack) {
      debugPrint('[RatingService] ❌ TRANSACTION FAILED: $e');
      debugPrint('[RatingService] 📜 StackTrace: $stack');
      rethrow;
    }
  }

  /// Menghapus rating pengguna yang sedang aktif beserta pembaruan statistik buku
  /// secara atomik menggunakan transaksi.
  ///
  /// Jika rating dihapus, seluruh counter agregat (jumlah penilai, total nilai,
  /// rata-rata, distribusi bintang) akan disesuaikan kembali.
  static Future<void> deleteRating(String bookId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User must be logged in.');
    
    final uid = user.uid;
    final ratingDocRef = _ratingsCol(bookId).doc(uid);
    final bookDocRef = _firestore.collection('books').doc(bookId);

    try {
      await _firestore.runTransaction((transaction) async {
        final ratingDocSnap = await transaction.get(ratingDocRef);
        final bookDocSnap = await transaction.get(bookDocRef);

        if (!ratingDocSnap.exists) return; // Nothing to delete

        final oldRating = (ratingDocSnap.data()?['rating'] as num?)?.toDouble() ?? 0.0;
        final oldReview = ratingDocSnap.data()?['review'] as String? ?? '';
        
        if (bookDocSnap.exists) {
          final bookData = bookDocSnap.data()!;
          int ratingsCount = (bookData['ratingsCount'] as int? ?? bookData['totalRatings'] as int? ?? 0);
          double totalRatingSum = (bookData['totalRatingSum'] as num? ?? 0.0).toDouble();
          int totalReviews = (bookData['totalReviews'] as int? ?? 0);
          double currentAverage = (bookData['averageRating'] as num? ?? 0.0).toDouble();

          // Koreksi data lama yang tidak konsisten sebelum menghitung pengurangan.
          if (totalRatingSum == 0.0 && ratingsCount > 0) {
            if (currentAverage > 0) {
              totalRatingSum = currentAverage * ratingsCount;
            } else {
              ratingsCount = 0;
            }
          }
          
          int star1 = bookData['star1'] as int? ?? 0;
          int star2 = bookData['star2'] as int? ?? 0;
          int star3 = bookData['star3'] as int? ?? 0;
          int star4 = bookData['star4'] as int? ?? 0;
          int star5 = bookData['star5'] as int? ?? 0;

          ratingsCount = ratingsCount > 0 ? ratingsCount - 1 : 0;
          totalRatingSum = totalRatingSum > oldRating ? totalRatingSum - oldRating : 0;
          if (oldReview.trim().isNotEmpty) {
            totalReviews = totalReviews > 0 ? totalReviews - 1 : 0;
          }
          
          if (oldRating == 1) star1 = (star1 > 0) ? star1 - 1 : 0;
          if (oldRating == 2) star2 = (star2 > 0) ? star2 - 1 : 0;
          if (oldRating == 3) star3 = (star3 > 0) ? star3 - 1 : 0;
          if (oldRating == 4) star4 = (star4 > 0) ? star4 - 1 : 0;
          if (oldRating == 5) star5 = (star5 > 0) ? star5 - 1 : 0;

          final bookUpdate = {
            'ratingsCount': ratingsCount,
            'totalRatingSum': totalRatingSum,
            'averageRating': ratingsCount > 0 ? totalRatingSum / ratingsCount : 0.0,
            'totalReviews': totalReviews,
            'updatedAt': FieldValue.serverTimestamp(),
            'star1': star1,
            'star2': star2,
            'star3': star3,
            'star4': star4,
            'star5': star5,
          };
          transaction.update(bookDocRef, bookUpdate);
        }
        transaction.delete(ratingDocRef);
      });
    } catch (e) {
      debugPrint('[RatingService] ❌ deleteRating error: $e');
      rethrow;
    }
  }
}
