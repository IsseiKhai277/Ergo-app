import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String userId;
  final String caption;
  final List<String> imageUrls;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;

  // Resolved from users collection (not stored in posts)
  final String posterName;
  final String posterPhotoUrl;
  final String posterRole;
  final double posterRating;

  // Runtime state (not stored in Firestore)
  final bool isLikedByCurrentUser;

  PostModel({
    required this.postId,
    required this.userId,
    required this.caption,
    required this.imageUrls,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    this.posterName = '',
    this.posterPhotoUrl = '',
    this.posterRole = '',
    this.posterRating = 0.0,
    this.isLikedByCurrentUser = false,
  });

  factory PostModel.fromMap(Map<String, dynamic> data, String documentId) {
    return PostModel(
      postId: documentId,
      userId: data['userId'] ?? '',
      caption: data['caption'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: (data['likeCount'] ?? 0) as int,
      commentCount: (data['commentCount'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'caption': caption,
      'imageUrls': imageUrls,
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': likeCount,
      'commentCount': commentCount,
    };
  }

  PostModel copyWith({
    String? postId,
    String? userId,
    String? caption,
    List<String>? imageUrls,
    DateTime? createdAt,
    int? likeCount,
    int? commentCount,
    String? posterName,
    String? posterPhotoUrl,
    String? posterRole,
    double? posterRating,
    bool? isLikedByCurrentUser,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      caption: caption ?? this.caption,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      posterName: posterName ?? this.posterName,
      posterPhotoUrl: posterPhotoUrl ?? this.posterPhotoUrl,
      posterRole: posterRole ?? this.posterRole,
      posterRating: posterRating ?? this.posterRating,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
    );
  }
}
