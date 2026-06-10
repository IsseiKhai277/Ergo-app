import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Resolves user profile data from the existing `users` collection.
/// DO NOT modify the users collection structure.
class FeedUserResolverService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // In-memory cache to reduce Firestore reads
  static final Map<String, Map<String, dynamic>> _cache = {};

  /// Returns the currently authenticated user's UID
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Fetches a user document from the `users` collection by UID.
  /// Uses an in-memory cache to minimize reads.
  static Future<Map<String, dynamic>?> getUserById(String uid) async {
    if (uid.isEmpty) return null;

    // Return from cache if available
    if (_cache.containsKey(uid)) {
      return _cache[uid];
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        _cache[uid] = doc.data()!;
        return doc.data();
      }
    } catch (e) {
      // Silently fail — feed cards will show fallback values
    }
    return null;
  }

  /// Clears the in-memory user profile cache
  static void clearCache() {
    _cache.clear();
  }
}
