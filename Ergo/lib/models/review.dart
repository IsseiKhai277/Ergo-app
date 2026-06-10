import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a review document in Firestore.
/// Path: reviews/{reviewId}
class Review {
  final String id;
  final String userId;       // The profile being reviewed
  final String reviewerName;
  final String reviewerPhotoUrl;
  final double rating;
  final String comment;
  final DateTime? createdAt;

  const Review({
    required this.id,
    required this.userId,
    required this.reviewerName,
    this.reviewerPhotoUrl = '',
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory Review.fromMap(Map<String, dynamic> map, String id) {
    return Review(
      id: id,
      userId: map['userId'] as String? ?? '',
      reviewerName: map['reviewerName'] as String? ?? 'Anonymous',
      reviewerPhotoUrl: map['reviewerPhotoUrl'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      comment: map['comment'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'reviewerName': reviewerName,
      'reviewerPhotoUrl': reviewerPhotoUrl,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
