import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:litera2/fitur/buku/model/model_buku.dart';

/// Layanan admin untuk mengelola data buku di Firestore.
class AdminService {
  static final _firestore = FirebaseFirestore.instance;

  static final CollectionReference _booksCol = _firestore.collection('books');

  static String newBookId() => _booksCol.doc().id;

  static Future<void> saveBook(BookModel book) {
    if (book.id.isEmpty) throw ArgumentError('ID buku wajib diisi sebelum disimpan.');
    return _booksCol.doc(book.id).set(book.toFirestore(), SetOptions(merge: true));
  }

  static Stream<List<BookModel>> watchAllBooks() {
    return _booksCol.orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => BookModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  static Future<int> getBooksCount() async {
    final snapshot = await _booksCol.count().get();
    return snapshot.count ?? 0;
  }

  static Future<List<BookModel>> getRecentBooks({int limit = 5}) async {
    final snapshot = await _booksCol.orderBy('createdAt', descending: true).limit(limit).get();
    return snapshot.docs
        .map((doc) => BookModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  static Future<void> addBook(BookModel book) async {
    final docRef = book.id.isEmpty ? _booksCol.doc() : _booksCol.doc(book.id);

    final bookWithId = BookModel(
      id: docRef.id,
      title: book.title,
      authors: book.authors,
      categories: book.categories,
      thumbnail: book.thumbnail,
      pdfDownloadLink: book.pdfDownloadLink,
      description: book.description,
      subtitle: book.subtitle,
      publisher: book.publisher,
      publishedDate: book.publishedDate,
      pageCount: book.pageCount,
      language: book.language,
      previewLink: book.previewLink,
      infoLink: book.infoLink,
      isEbook: book.isEbook,
      createdAt: book.createdAt,
    );

    await docRef.set(bookWithId.toFirestore());
  }

  static Future<void> updateBook(BookModel book) async {
    if (book.id.isEmpty) throw Exception('ID buku tidak boleh kosong saat memperbarui data.');
    await _booksCol.doc(book.id).set(book.toFirestore(), SetOptions(merge: true));
  }

  static Future<void> deleteBook(String bookId) async {
    final ratingsCol = _booksCol.doc(bookId).collection('ratings');
    final ratingsSnap = await ratingsCol.get();

    if (ratingsSnap.docs.isNotEmpty) {
      var batch = _firestore.batch();
      var batchCount = 0;

      for (final doc in ratingsSnap.docs) {
        batch.delete(doc.reference);
        batchCount++;

        if (batchCount >= 499) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) await batch.commit();
    }

    await _booksCol.doc(bookId).delete();
  }
}
