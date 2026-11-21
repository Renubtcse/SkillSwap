
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create a new user profile
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
    required String college,
  }) async {
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'college': college,
      'credits': 10,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get existing user profile
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final document = await _db.collection('users').doc(uid).get();

    if (document.exists) {
      return document.data();
    }

    return null;
  }

  // Create profile only if it does not already exist
  Future<void> ensureUserProfile({
    required String uid,
    required String name,
    required String email,
    required String college,
  }) async {
    final existingProfile = await getUserProfile(uid);

    if (existingProfile == null) {
      await createUserProfile(
        uid: uid,
        name: name,
        email: email,
        college: college,
      );
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    required String name,
    required String email,
    required String college,
  }) async {
    await _db.collection('users').doc(uid).update({
      'name': name,
      'email': email,
      'college': college,
    });
  }
}
