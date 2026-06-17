import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_profile.dart';
import '../models/review.dart';

/// Handles all profile-related Firestore and Storage operations.
class ProfileService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // ─── Fetch Profile (real-time stream) ────────────────────────────────────────
  static Stream<UserProfile?> profileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfile.fromMap(doc.data()!, uid);
    });
  }

  // ─── Fetch Profile (one-time) ─────────────────────────────────────────────
  static Future<UserProfile?> fetchProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromMap(doc.data()!, uid);
  }

  // ─── Update Profile Fields ────────────────────────────────────────────────
  static Future<void> updateProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    // Always update the timestamp
    data['updatedAt'] = FieldValue.serverTimestamp();

    // Recalculate profileComplete flag if relevant fields changed
    final doc = await _db.collection('users').doc(uid).get();
    final existing = doc.data() ?? {};
    final merged = {...existing, ...data};

    final bool complete = _calcProfileComplete(merged);
    data['profileComplete'] = complete;
    data['verified'] = complete;

    await _db.collection('users').doc(uid).update(data);
  }

  // ─── Upload Profile Image ──────────────────────────────────────────────────
  /// Uploads [imageFile] to Firebase Storage and returns the download URL.
  static Future<String> uploadProfileImage({
    required String uid,
    required File imageFile,
  }) async {
    final ref = _storage.ref().child('profile_images/$uid/avatar.jpg');
    final task = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  // ─── Save Profile Image URL ────────────────────────────────────────────────
  static Future<void> saveProfileImageUrl({
    required String uid,
    required String imageUrl,
  }) async {
    await _db.collection('users').doc(uid).update({
      'photoUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Also update Firebase Auth display photo
    await FirebaseAuth.instance.currentUser?.updatePhotoURL(imageUrl);
  }

  // ─── Upload Resume ─────────────────────────────────────────────────────────
  /// Uploads a resume file (PDF/DOCX) to Firebase Storage and returns URL.
  static Future<String> uploadResume({
    required String uid,
    required File resumeFile,
    required String fileName,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    final ref = _storage.ref().child('resumes/$uid/resume.$extension');

    final contentType = extension == 'pdf'
        ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

    // Use readAsBytes and putData to bypass file path issues on Android/iOS
    final bytes = await resumeFile.readAsBytes();
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return await task.ref.getDownloadURL();
  }

  // ─── Save Resume URL ───────────────────────────────────────────────────────
  static Future<void> saveResumeUrl({
    required String uid,
    required String resumeUrl,
  }) async {
    await _db.collection('users').doc(uid).update({
      'resumeUrl': resumeUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Update Skills ─────────────────────────────────────────────────────────
  static Future<void> updateSkills({
    required String uid,
    required List<String> skills,
  }) async {
    await _db.collection('users').doc(uid).update({
      'skills': skills,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Fetch Reviews (real-time stream) ────────────────────────────────────
  static Stream<List<Review>> reviewsStream(String uid) {
    return _db
        .collection('reviews')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Review.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // ─── Create Test Review (dev helper) ──────────────────────────────────────
  static Future<void> addReview({required Review review}) async {
    await _db.collection('reviews').add(review.toMap());

    // Recalculate average rating
    final reviews = await _db
        .collection('reviews')
        .where('userId', isEqualTo: review.userId)
        .get();

    final total = reviews.docs.fold<double>(
      0.0,
      (acc, doc) => acc + ((doc.data()['rating'] as num?)?.toDouble() ?? 0.0),
    );
    final average = reviews.docs.isEmpty ? 0.0 : total / reviews.docs.length;

    await _db.collection('users').doc(review.userId).update({
      'rating': average,
      'reviewCount': reviews.docs.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────
  static bool _calcProfileComplete(Map<String, dynamic> data) {
    final photoUrl = data['photoUrl'] as String? ?? '';
    final fullName = data['fullName'] as String? ?? '';
    final phoneNumber = data['phoneNumber'] as String? ?? '';
    final skills = data['skills'] as List? ?? [];
    final resumeUrl = data['resumeUrl'] as String? ?? '';

    int filled = 0;
    if (photoUrl.isNotEmpty) filled++;
    if (fullName.isNotEmpty) filled++;
    if (phoneNumber.isNotEmpty) filled++;
    if (skills.isNotEmpty) filled++;
    if (resumeUrl.isNotEmpty) filled++;

    return ((filled / 5) * 100) >= 80;
  }
}
