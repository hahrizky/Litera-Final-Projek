import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:litera2/fitur/buku/model/model_buku.dart';
import 'package:litera2/fitur/buku/service/service_buku_lokal.dart';

enum LoadState { idle, loading, loaded, error }

/// Mengelola state katalog buku: kategori, pencarian, dan daftar top-rated.
/// Data yang dimuat hanya metadata buku; file PDF diakses terpisah saat membaca.
class BookProvider extends ChangeNotifier {
  static const _pageSize = 20;
  final _books = FirebaseFirestore.instance.collection('books');

  final List<BookModel> _categoryBooks = [];
  List<BookModel> get categoryBooks => List.unmodifiable(_categoryBooks);
  LoadState _categoryState = LoadState.idle;
  LoadState get categoryState => _categoryState;
  String _categoryError = '';
  String get categoryError => _categoryError;
  String _selectedCategory = 'Semua';
  String get selectedCategory => _selectedCategory;
  bool _categoryHasMore = true;
  bool get categoryHasMore => _categoryHasMore;
  bool _isLoadingMore = false;
  DocumentSnapshot<Map<String, dynamic>>? _lastCategoryDocument;

  final List<BookModel> _searchResults = [];
  List<BookModel> get searchResults => List.unmodifiable(_searchResults);
  LoadState _searchState = LoadState.idle;
  LoadState get searchState => _searchState;
  String _searchError = '';
  String get searchError => _searchError;
  bool _searchHasMore = false;
  bool get searchHasMore => _searchHasMore;

  // ── Top Rated Books ─────────────────────────────────────────────────────
  final List<BookModel> _topRatedBooks = [];
  List<BookModel> get topRatedBooks => List.unmodifiable(_topRatedBooks);
  LoadState _topRatedState = LoadState.idle;
  LoadState get topRatedState => _topRatedState;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _topRatedSub;

  Future<void> loadTopRatedBooks({bool force = false}) async {
    if (_topRatedState == LoadState.loading) return;
    if (_topRatedBooks.isNotEmpty && !force) return;
    _topRatedState = LoadState.loading;
    notifyListeners();
    try {
      final snapshot = await _books
          .orderBy('averageRating', descending: true)
          .where('averageRating', isGreaterThan: 0)
          .limit(3) // Hanya 3 buku teratas.
          .get();
      _topRatedBooks.clear();
      // Hanya tampilkan buku yang benar-benar sudah dinilai pengguna.
      _topRatedBooks.addAll(
        snapshot.docs.map((doc) => BookModel.fromFirestore(doc.data(), doc.id)),
      );
      _topRatedState = LoadState.loaded;
    } catch (e) {
      _topRatedState = LoadState.error;
    }
    notifyListeners();
  }

  /// Memantau leaderboard secara realtime agar urutan buku diperbarui
  /// segera setelah ada perubahan rating dari pengguna mana pun.
  void startTopRatedListener({bool force = false}) {
    if (_topRatedSub != null && !force) return;
    if (force) {
      _topRatedSub?.cancel();
      _topRatedSub = null;
    }
    _topRatedState = LoadState.loading;
    notifyListeners();

    _topRatedSub = _books
        .where('averageRating', isGreaterThan: 0)
        .orderBy('averageRating', descending: true)
        .limit(3)
        .snapshots()
        .listen((snapshot) {
      _topRatedBooks
        ..clear()
        ..addAll(
          snapshot.docs
              .map((doc) => BookModel.fromFirestore(doc.data(), doc.id))
              .where((book) => book.ratingsCount > 0),
        );
      _topRatedState = LoadState.loaded;
      notifyListeners();
    }, onError: (_) {
      _topRatedState = LoadState.error;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _topRatedSub?.cancel();
    super.dispose();
  }

  // Alias untuk kompatibilitas widget dashboard yang masih menggunakan nama lama.
  List<BookModel> get popularBooks => _categoryBooks;
  List<BookModel> get newestBooks => _categoryBooks;
  List<BookModel> get recommendedBooks => _categoryBooks;
  List<BookModel> get trendingBooks => _categoryBooks;
  LoadState get dashboardState => _categoryState;
  String get dashboardError => _categoryError;
  bool get isDashboardLoading => _categoryState == LoadState.loading;
  bool get isCategoryLoading => _categoryState == LoadState.loading || _isLoadingMore;
  bool get isSearchLoading => _searchState == LoadState.loading;
  List<BookModel> get relatedBooks => const [];
  LoadState get relatedState => LoadState.loaded;

  Future<void> loadDashboard({bool force = false}) => loadCategory('Semua', '');

  Future<void> loadCategory(String category, String _) async {
    if (_categoryState == LoadState.loading) return;
    _selectedCategory = category;
    _categoryBooks.clear();
    _lastCategoryDocument = null;
    _categoryHasMore = true;
    _categoryState = LoadState.loading;
    _categoryError = '';
    notifyListeners();
    await _fetchCategoryPage();
  }

  Future<void> loadMoreCategory(String _) async {
    if (!_categoryHasMore || _isLoadingMore || _categoryState == LoadState.loading) return;
    _isLoadingMore = true;
    notifyListeners();
    await _fetchCategoryPage();
  }

  Future<void> _fetchCategoryPage() async {
    try {
      Query<Map<String, dynamic>> query = _books;
      if (_selectedCategory == 'Semua') {
        query = query.orderBy('createdAt', descending: true);
      } else {
        query = query.where('categories', arrayContains: _selectedCategory);
      }
      query = query.limit(_pageSize);
      if (_lastCategoryDocument != null) query = query.startAfterDocument(_lastCategoryDocument!);
      final snapshot = await query.get();
      if (snapshot.docs.isEmpty && _lastCategoryDocument == null) {
        _categoryBooks.addAll(LocalBookService.getBooksByCategory(_selectedCategory));
        _categoryHasMore = false;
        _categoryState = _categoryBooks.isEmpty ? LoadState.error : LoadState.loaded;
        if (_categoryBooks.isEmpty) _categoryError = 'errorNoBooks';
        return;
      }
      _categoryBooks.addAll(snapshot.docs.map((doc) => BookModel.fromFirestore(doc.data(), doc.id)));
      _lastCategoryDocument = snapshot.docs.isEmpty ? _lastCategoryDocument : snapshot.docs.last;
      _categoryHasMore = snapshot.docs.length == _pageSize;
      _categoryState = LoadState.loaded;
    } catch (e) {
      _categoryError = _friendlyError(e);
      _categoryState = _categoryBooks.isEmpty ? LoadState.error : LoadState.loaded;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Pencarian prefix berbasis field [titleLowercase] — efisien karena tidak
  /// mengunduh seluruh koleksi untuk difilter di sisi klien.
  Future<void> searchBooks(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return clearSearch();
    _searchState = LoadState.loading;
    _searchError = '';
    _searchResults.clear();
    notifyListeners();
    try {
      final snapshot = await _books
          .orderBy('titleLowercase')
          .startAt([normalized])
          .endAt(['$normalized\uf8ff'])
          .limit(_pageSize)
          .get();
      _searchResults.addAll(snapshot.docs.map((doc) => BookModel.fromFirestore(doc.data(), doc.id)));
      if (_searchResults.isEmpty) {
        _searchResults.addAll(LocalBookService.searchBooks(normalized));
      }
      _searchHasMore = snapshot.docs.length == _pageSize;
      _searchState = LoadState.loaded;
    } catch (e) {
      _searchError = _friendlyError(e);
      _searchState = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> loadMoreSearch() async {}

  void clearSearch() {
    _searchResults.clear();
    _searchState = LoadState.idle;
    _searchError = '';
    _searchHasMore = false;
    notifyListeners();
  }

  Future<void> loadRelatedBooks(BookModel _) async {}

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('permission-denied')) return 'errorPermission';
    if (text.contains('unavailable')) return 'errorNoInternet';
    return 'errorGeneral';
  }
}