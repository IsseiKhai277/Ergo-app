import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String commentId;
  final String postId;
  final String userId;
  final String commentText;
  final DateTime createdAt;

  // Resolved from users collection
  final String commenterName;
  final String commenterPhotoUrl;

  CommentModel({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.commentText,
    required this.createdAt,
    this.commenterName = '',
    this.commenterPhotoUrl = '',
  });

  factory CommentModel.fromMap(Map<String, dynamic> data, String documentId) {
    return CommentModel(
      commentId: documentId,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      commentText: data['commentText'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'commentText': commentText,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  CommentModel copyWith({
    String? commenterName,
    String? commenterPhotoUrl,
  }) {
    return CommentModel(
      commentId: commentId,
      postId: postId,
      userId: userId,
      commentText: commentText,
      createdAt: createdAt,
      commenterName: commenterName ?? this.commenterName,
      commenterPhotoUrl: commenterPhotoUrl ?? this.commenterPhotoUrl,
    );
  }
}
