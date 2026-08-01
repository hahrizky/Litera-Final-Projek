import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:litera2/fitur/profil/model/model_profil.dart';

import 'package:litera2/core/konstan/konstan_aplikasi.dart';

class UserService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static CollectionReference<Map<String, dynamic>> get _usersCol =>
      _firestore.collection('users');

  static String? get _uid => _auth.currentUser?.uid;

  /// Stream user profile (realtime)
  static Stream<UserProfileModel?> watchProfile() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _usersCol.doc(uid).snapshots().asyncMap((doc) async {
      if (!doc.exists) return null;
      final profile = UserProfileModel.fromFirestore(doc.data()!, doc.id);
      
      // Auto-sync admin role jika email termasuk daftar admin tetapi role di DB masih 'user'
      final isAdminEmail = AppConstants.adminEmails.contains(profile.email.toLowerCase().trim());
      if (isAdminEmail && profile.role != 'admin') {
        await updateFields({'role': 'admin'});
        return profile.copyWith(role: 'admin');
      }
      return profile;
    });
  }

  /// Create or update user profile
  static Future<void> saveProfile(UserProfileModel profile) async {
    final isAdminEmail = AppConstants.adminEmails.contains(profile.email.toLowerCase().trim());
    final targetProfile = isAdminEmail ? profile.copyWith(role: 'admin') : profile;
    await _usersCol.doc(targetProfile.uid).set(targetProfile.toFirestore(), SetOptions(merge: true));
  }

  /// Get user profile once
  static Future<UserProfileModel?> getProfile() async {
    final uid = _uid;
    if (uid == null) return null;
    final doc = await _usersCol.doc(uid).get();
    if (!doc.exists) return null;
    final profile = UserProfileModel.fromFirestore(doc.data()!, doc.id);
    
    // Auto-sync admin role jika belum 'admin' di DB
    final isAdminEmail = AppConstants.adminEmails.contains(profile.email.toLowerCase().trim());
    if (isAdminEmail && profile.role != 'admin') {
      await updateFields({'role': 'admin'});
      return profile.copyWith(role: 'admin');
    }
    return profile;
  }

  /// Update specific fields
  static Future<void> updateFields(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) return;
    await _usersCol.doc(uid).update(data);
  }
}
