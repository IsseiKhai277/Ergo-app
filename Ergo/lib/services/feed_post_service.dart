import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import 'feed_user_resolver_service.dart';

class FeedPostService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const int _pageSize = 15;

  // ─── Create Post ─────────────────────────────────────────────────────────

  /// Creates a new post in the `posts` collection.
  /// Optionally uploads images to Firebase Storage first.
  static Future<String> createPost({
    required String caption,
    List<File> imageFiles = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Create post doc first to get the ID
    final docRef = _firestore.collection('posts').doc();
    final postId = docRef.id;

    // Convert images to Base64 strings to store directly in Firestore
    final List<String> imageUrls = [];
    for (final file in imageFiles) {
      final bytes = await file.readAsBytes();
      imageUrls.add(base64Encode(bytes));
    }

    // Save post document
    await docRef.set({
      'postId': postId,
      'userId': user.uid,
      'caption': caption.trim(),
      'imageUrls': imageUrls,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'commentCount': 0,
    });

    return postId;
  }

  // ─── Delete Post ─────────────────────────────────────────────────────────

  static Future<void> deletePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final doc = await _firestore.collection('posts').doc(postId).get();
    if (doc.exists && doc.data()?['userId'] == user.uid) {
      await doc.reference.delete();
    } else {
      throw Exception('Unauthorized to delete this post');
    }
  }

  // ─── Fetch Posts Stream ───────────────────────────────────────────────────

  /// Real-time stream of posts sorted by createdAt DESC.
  /// Resolves user info from the `users` collection for each post.
  static Stream<List<PostModel>> fetchPostsStream({
    DocumentSnapshot? startAfter,
  }) {
    Query query = _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().asyncMap((snapshot) async {
      final currentUid = _auth.currentUser?.uid ?? '';
      final List<PostModel> posts = [];

      for (final doc in snapshot.docs) {
        final post = PostModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );

        // Resolve user info from users collection
        final userData =
            await FeedUserResolverService.getUserById(post.userId);

        // Check if current user has liked this post
        bool isLiked = false;
        if (currentUid.isNotEmpty) {
          final likeDoc = await _firestore
              .collection('posts')
              .doc(post.postId)
              .collection('likes')
              .doc(currentUid)
              .get();
          isLiked = likeDoc.exists;
        }

        posts.add(post.copyWith(
          posterName: userData?['fullName'] ?? 'Unknown',
          posterPhotoUrl: userData?['photoUrl'] ?? '',
          posterRole: userData?['role'] ?? '',
          posterRating: (userData?['rating'] ?? 0.0).toDouble(),
          posterResumeUrl: userData?['resumeUrl'] as String? ?? '',
          isLikedByCurrentUser: isLiked,
        ));
      }

      return posts;
    });
  }

  // ─── Get Single Post ──────────────────────────────────────────────────────

  static Future<PostModel?> getPostById(String postId) async {
    final doc = await _firestore.collection('posts').doc(postId).get();
    if (!doc.exists) return null;

    final post = PostModel.fromMap(doc.data()!, doc.id);
    final userData = await FeedUserResolverService.getUserById(post.userId);

    return post.copyWith(
      posterName: userData?['fullName'] ?? 'Unknown',
      posterPhotoUrl: userData?['photoUrl'] ?? '',
      posterRole: userData?['role'] ?? '',
      posterRating: (userData?['rating'] ?? 0.0).toDouble(),
      posterResumeUrl: userData?['resumeUrl'] as String? ?? '',
    );
  }

  // ─── Like System ─────────────────────────────────────────────────────────

  /// Likes a post — creates a like document and increments likeCount
  static Future<void> likePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final likeRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid);

    await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
    await incrementLikeCount(postId);
  }

  /// Unlikes a post — removes the like document and decrements likeCount
  static Future<void> unlikePost(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final likeRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid);

    await likeRef.delete();
    await decrementLikeCount(postId);
  }

  /// Toggles like — likes if not liked, unlikes if already liked
  static Future<bool> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final likeRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(user.uid);

    final likeDoc = await likeRef.get();
    if (likeDoc.exists) {
      await unlikePost(postId);
      return false; // now unliked
    } else {
      await likePost(postId);
      return true; // now liked
    }
  }

  static Future<void> incrementLikeCount(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'likeCount': FieldValue.increment(1),
    });
  }

  static Future<void> decrementLikeCount(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'likeCount': FieldValue.increment(-1),
    });
  }
}
