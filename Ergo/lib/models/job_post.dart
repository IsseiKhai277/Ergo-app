import 'package:cloud_firestore/cloud_firestore.dart';

class JobPost {
  final String id;
  final String posterId;
  final String posterName;
  final String posterPhotoUrl;
  final String title;
  final String description;
  final double price;
  final String location;
  final DateTime createdAt;

  JobPost({
    required this.id,
    required this.posterId,
    required this.posterName,
    required this.posterPhotoUrl,
    required this.title,
    required this.description,
    required this.price,
    required this.location,
    required this.createdAt,
  });

  factory JobPost.fromMap(Map<String, dynamic> data, String documentId) {
    return JobPost(
      id: documentId,
      posterId: data['posterId'] ?? '',
      posterName: data['posterName'] ?? 'Unknown User',
      posterPhotoUrl: data['posterPhotoUrl'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      location: data['location'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'posterId': posterId,
      'posterName': posterName,
      'posterPhotoUrl': posterPhotoUrl,
      'title': title,
      'description': description,
      'price': price,
      'location': location,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
