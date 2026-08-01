# Arsitektur Litera

## Batas tanggung jawab

- Firebase Authentication: login, registrasi, logout, verifikasi email.
- Cloud Firestore: `books` (metadata), `users`, `bookmarks`, `history`, dan `favorites`.
- Supabase Storage: bucket publik `cover_book` untuk cover dan `book` untuk PDF.
- Cloudinary: hanya foto profil, melalui `ImageUploadService`.

## Konfigurasi runtime

Jalankan aplikasi dengan kredensial Supabase berikut; jangan commit nilai sebenarnya.

```powershell
flutter run --dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=ANON_KEY
```

Bucket Supabase harus mengizinkan upload admin sesuai policy RLS Anda. Karena aplikasi
mobile tidak dapat menyimpan service-role key, produksi sebaiknya memakai signed upload
URL atau Edge Function yang memverifikasi JWT Firebase/admin sebelum upload.

## Firestore

Deploy aturan dan indeks setelah meninjau project Firebase:

```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

Tulisan ke `books` membutuhkan custom claim Firebase `admin: true`. Claim ini wajib
ditetapkan dengan Firebase Admin SDK, bukan oleh aplikasi klien. Field `role` di
`users` hanya boleh dipakai untuk tampilan UI.

## Alur buku

1. Admin memilih cover dan PDF.
2. Aset diunggah ke Supabase, lalu URL publiknya disimpan bersama metadata di Firestore.
3. Explore mengambil halaman metadata Firestore (20 item), cover ditampilkan dengan cache.
4. PDF tidak diunduh di Explore/detail; `SfPdfViewer.network` memuatnya saat pembaca dibuka.
