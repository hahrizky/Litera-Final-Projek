import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:litera2/fitur/profil/model/model_profil.dart';
import 'package:litera2/fitur/profil/service/service_user.dart';
import 'package:litera2/fitur/buku/service/service_riwayat.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Helper: cek apakah user adalah admin
  // Prioritas: (1) custom claims di ID token, (2) field role di Firestore
  Future<bool> _isAdminUser(User user) async {
    // Lapis 1: cek custom claims (forceRefresh agar token selalu fresh)
    try {
      final idTokenResult = await user.getIdTokenResult(true);
      if (idTokenResult.claims?['role'] == 'admin') return true;
    } catch (_) {}

    // Lapis 2: cek field role di Firestore sebagai fallback
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()?['role'] == 'admin') return true;
    } catch (_) {}

    return false;
  }

  // 1. LOGIN GOOGLE
  Future<String> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) return "Login dibatalkan";

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);

      // Blokir akun admin dari aplikasi user
      if (userCred.user != null && await _isAdminUser(userCred.user!)) {
        await _auth.signOut();
        await _googleSignIn.signOut();
        return "Akses ditolak. Akun Anda tidak memiliki izin untuk masuk ke aplikasi ini.";
      }

      // Sync local reading history ke Firestore
      await ReadingHistoryService.syncLocalHistoryToFirestore();

      return "success";
    } catch (e) {
      return e.toString();
    }
  }

  // 2. REGISTER
  Future<String> register(String email, String password, String name) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        // Buat profil user di Firestore
        final profile = UserProfileModel(
          uid: user.uid,
          displayName: name,
          email: email,
          createdAt: DateTime.now(),
        );
        await UserService.saveProfile(profile);

        // Sync local reading history ke Firestore
        await ReadingHistoryService.syncLocalHistoryToFirestore();
      }

      return "success";
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Terjadi kesalahan";
    }
  }

  // 3. LOGIN EMAIL
  Future<String> login(String email, String password) async {
    try {
      UserCredential credential =
          await _auth.signInWithEmailAndPassword(email: email, password: password);

      final user = credential.user;
      if (user != null) {
        // Blokir akun admin dari aplikasi user
        if (await _isAdminUser(user)) {
          await _auth.signOut();
          return "Akses ditolak. Akun Anda tidak memiliki izin untuk masuk ke aplikasi ini.";
        }

        // Sync profile jika belum ada
        final existing = await UserService.getProfile();
        if (existing == null) {
          final profile = UserProfileModel(
            uid: user.uid,
            displayName: user.displayName ?? 'Pembaca',
            email: email,
            createdAt: DateTime.now(),
          );
          await UserService.saveProfile(profile);
        }

        // Sync local reading history ke Firestore
        await ReadingHistoryService.syncLocalHistoryToFirestore();
      }
      return "success";
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Email atau Password salah";
    }
  }

  // 4. LOGOUT
  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint("Error saat logout: $e");
    }
  }

  // 5. RESET PASSWORD
  Future<String> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return "success";
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return "Email tidak terdaftar";
      } else if (e.code == 'invalid-email') {
        return "Format email tidak valid";
      }
      return "Terjadi kesalahan";
    } catch (e) {
      return "Gagal mengirim email";
    }
  }

  // 6. DELETE ACCOUNT
  Future<String> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Hapus data pengguna di Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        
        // Hapus otentikasi
        await user.delete();
        if (await _googleSignIn.isSignedIn()) {
          await _googleSignIn.signOut();
        }
      }
      return "success";
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return "requires-recent-login";
      }
      return e.message ?? "Terjadi kesalahan saat menghapus akun";
    } catch (e) {
      return e.toString();
    }
  }
}

