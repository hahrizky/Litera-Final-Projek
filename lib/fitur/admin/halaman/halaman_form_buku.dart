import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:litera2/core/konstan/warna_aplikasi.dart';
import 'package:litera2/fitur/buku/model/model_buku.dart';
import 'package:litera2/fitur/admin/service/service_admin.dart';
import 'package:litera2/global/service/service_supabase.dart';
import 'package:litera2/fitur/buku/widget/cover_buku.dart';

/// Form admin sengaja hanya menangani metadata inti serta dua aset Supabase.
class BookFormPage extends StatefulWidget {
  const BookFormPage({super.key, this.book});
  final BookModel? book;

  @override
  State<BookFormPage> createState() => _BookFormPageState();
}

class _BookFormPageState extends State<BookFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _category;
  File? _coverFile;
  File? _pdfFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.book?.title ?? '');
    _description = TextEditingController(text: widget.book?.description ?? '');
    _category = TextEditingController(text: widget.book?.categoryDisplay ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null && mounted) setState(() => _coverFile = File(image.path));
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path != null && mounted) setState(() => _pdfFile = File(path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.book == null && (_coverFile == null || _pdfFile == null)) {
      _showError('Cover dan file PDF wajib diunggah.');
      return;
    }
    setState(() => _saving = true);
    try {
      final id = widget.book?.id ?? AdminService.newBookId();
      final storage = SupabaseStorageService.instance;
      final coverUrl = _coverFile == null
          ? widget.book!.bestCover
          : await storage.uploadCover(bookId: id, file: _coverFile!);
      final pdfUrl = _pdfFile == null
          ? widget.book!.pdfDownloadLink
          : await storage.uploadPdf(bookId: id, file: _pdfFile!);
      final book = BookModel(
        id: id,
        title: _title.text.trim(),
        description: _description.text.trim(),
        categories: [_category.text.trim()],
        thumbnail: coverUrl,
        smallThumbnail: coverUrl,
        pdfDownloadLink: pdfUrl,
        isEbook: true,
        createdAt: widget.book?.createdAt ?? DateTime.now(),
      );
      await AdminService.saveBook(book);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buku berhasil disimpan.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      _showError('Gagal menyimpan buku: ${error.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.book == null ? 'Tambah Buku' : 'Edit Buku'),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: _coverFile == null
                  ? BookCoverWidget(
                      imageUrl: widget.book?.bestCover,
                      width: 120,
                      height: 170,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _coverFile!,
                        width: 120,
                        height: 170,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickCover,
              icon: const Icon(Icons.image_outlined),
              label: Text(_coverFile == null ? 'Upload Cover' : 'Ganti Cover'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(
                _pdfFile == null
                    ? 'Upload PDF'
                    : _pdfFile!.uri.pathSegments.last,
              ),
            ),
            const SizedBox(height: 20),
            _field(_title, 'Title', required: true),
            const SizedBox(height: 12),
            _field(_category, 'Category', required: true),
            const SizedBox(height: 12),
            _field(_description, 'Description', lines: 5, required: true),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Simpan Buku'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    int lines = 1,
    bool required = false,
  }) => TextFormField(
    controller: controller,
    maxLines: lines,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    validator: required
        ? (value) => value == null || value.trim().isEmpty
              ? '$label wajib diisi.'
              : null
        : null,
  );
}
