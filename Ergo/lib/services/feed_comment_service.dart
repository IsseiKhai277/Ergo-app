import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comment_model.dart';
import 'feed_user_resolver_service.dart';

class FeedCommentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── Add Comment ─────────────────────────────────────────────────────────

  /// Adds a comment to a post and increments the post's commentCount
  static Future<void> addComment({
    required String postId,
    required String commentText,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    if (commentText.trim().isEmpty) return;

    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc();

    await commentRef.set({
      'commentId': commentRef.id,
      'postId': postId,
      'userId': user.uid,
      'commentText': commentText.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment comment count on the post document
    await _firestore.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  // ─── Fetch Comments (one-time) ────────────────────────────────────────────

  /// Fetches comments for a post once, with user info resolved
  static Future<List<CommentModel>> fetchComments(String postId) async {
    final snapshot = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .get();

    return _resolveCommentUsers(snapshot.docs);
  }

  // ─── Listen Comments (real-time) ─────────────────────────────────────────

  /// Returns a real-time stream of comments for a post, with user info resolved
  static Stream<List<CommentModel>> listenComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .asyncMap((snapshot) => _resolveCommentUsers(snapshot.docs));
  }

  // ─── Comment Count ────────────────────────────────────────────────────────

  /// Returns the current comment count for a post
  static Future<int> getCommentCount(String postId) async {
    final snapshot = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static Future<List<CommentModel>> _resolveCommentUsers(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final List<CommentModel> comments = [];

    for (final doc in docs) {
      final comment = CommentModel.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );

      final userData =
          await FeedUserResolverService.getUserById(comment.userId);

      comments.add(comment.copyWith(
        commenterName: userData?['fullName'] ?? 'Unknown',
        commenterPhotoUrl: userData?['photoUrl'] ?? '',
      ));
    }

    return comments;
  }
}
