import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Storage khusus aset buku. Jangan gunakan layanan ini untuk foto profil.
class SupabaseStorageService {
  SupabaseStorageService._();

  static final instance = SupabaseStorageService._();
  static const _coverBucket = 'cover_book';
  static const _bookBucket = 'book';

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> uploadCover({required String bookId, required File file}) {
    return _upload(
      bucket: _coverBucket,
      path: '$bookId/cover${_extension(file.path, fallback: '.jpg')}',
      file: file,
      contentType: _imageContentType(file.path),
    );
  }

  Future<String> uploadPdf({required String bookId, required File file}) {
    return _upload(
      bucket: _bookBucket,
      path: '$bookId/book.pdf',
      file: file,
      contentType: 'application/pdf',
    );
  }

  Future<String> _upload({
    required String bucket,
    required String path,
    required File file,
    required String contentType,
  }) async {
    if (!file.existsSync()) {
      throw StateError('File tidak ditemukan: ${file.path}');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('File kosong: ${file.path}');
    }

    try {
      await _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '31536000',
              contentType: contentType,
              upsert: true,
            ),
          );
    } on StorageException catch (error) {
      throw Exception('Upload ke Supabase gagal: ${error.message}');
    } catch (error) {
      throw Exception('Upload ke Supabase gagal: $error');
    }

    return _client.storage.from(bucket).getPublicUrl(path);
  }

  String _extension(String path, {required String fallback}) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? fallback : path.substring(dot).toLowerCase();
  }

  String _imageContentType(String path) =>
      switch (_extension(path, fallback: '.jpg')) {
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        _ => 'image/jpeg',
      };
}
