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
  final DateTime? scheduledAt;

  // Worker assignment & lifecycle
  final String workerId;
  final String workerName;
  final String workerPhotoUrl;
  final String status; // 'open' | 'accepted' | 'active' | 'completed'

  // Job location coordinates (set by client when posting)
  final double? jobLatitude;
  final double? jobLongitude;

  // Worker live tracking coordinates (updated every ~7 seconds while active)
  final double? workerLatitude;
  final double? workerLongitude;

  // Chat/Offer integration
  final String? conversationId;
  final String? messageId;

  // Completion data
  final String? completionPhoto;
  final String? completionDescription;
  final double? rating;

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
    this.scheduledAt,
    this.workerId = '',
    this.workerName = '',
    this.workerPhotoUrl = '',
    this.status = 'open',
    this.jobLatitude,
    this.jobLongitude,
    this.workerLatitude,
    this.workerLongitude,
    this.conversationId,
    this.messageId,
    this.completionPhoto,
    this.completionDescription,
    this.rating,
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
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate(),
      workerId: data['workerId'] ?? '',
      workerName: data['workerName'] ?? '',
      workerPhotoUrl: data['workerPhotoUrl'] ?? '',
      status: data['status'] ?? 'open',
      jobLatitude: (data['jobLatitude'] as num?)?.toDouble(),
      jobLongitude: (data['jobLongitude'] as num?)?.toDouble(),
      workerLatitude: (data['workerLatitude'] as num?)?.toDouble(),
      workerLongitude: (data['workerLongitude'] as num?)?.toDouble(),
      conversationId: data['conversationId'] as String?,
      messageId: data['messageId'] as String?,
      completionPhoto: data['completionPhoto'] as String?,
      completionDescription: data['completionDescription'] as String?,
      rating: (data['rating'] as num?)?.toDouble(),
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
      'workerId': workerId,
      'workerName': workerName,
      'workerPhotoUrl': workerPhotoUrl,
      'status': status,
      if (scheduledAt != null)
        'scheduledAt': Timestamp.fromDate(scheduledAt!),
      if (jobLatitude != null) 'jobLatitude': jobLatitude,
      if (jobLongitude != null) 'jobLongitude': jobLongitude,
      if (conversationId != null) 'conversationId': conversationId,
      if (messageId != null) 'messageId': messageId,
      if (completionPhoto != null) 'completionPhoto': completionPhoto,
      if (completionDescription != null)
        'completionDescription': completionDescription,
      if (rating != null) 'rating': rating,
    };
  }

  JobPost copyWith({
    String? id,
    String? posterId,
    String? posterName,
    String? posterPhotoUrl,
    String? title,
    String? description,
    double? price,
    String? location,
    DateTime? createdAt,
    DateTime? scheduledAt,
    String? workerId,
    String? workerName,
    String? workerPhotoUrl,
    String? status,
    double? jobLatitude,
    double? jobLongitude,
    double? workerLatitude,
    double? workerLongitude,
    String? conversationId,
    String? messageId,
    String? completionPhoto,
    String? completionDescription,
    double? rating,
  }) {
    return JobPost(
      id: id ?? this.id,
      posterId: posterId ?? this.posterId,
      posterName: posterName ?? this.posterName,
      posterPhotoUrl: posterPhotoUrl ?? this.posterPhotoUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      workerPhotoUrl: workerPhotoUrl ?? this.workerPhotoUrl,
      status: status ?? this.status,
      jobLatitude: jobLatitude ?? this.jobLatitude,
      jobLongitude: jobLongitude ?? this.jobLongitude,
      workerLatitude: workerLatitude ?? this.workerLatitude,
      workerLongitude: workerLongitude ?? this.workerLongitude,
      conversationId: conversationId ?? this.conversationId,
      messageId: messageId ?? this.messageId,
      completionPhoto: completionPhoto ?? this.completionPhoto,
      completionDescription: completionDescription ?? this.completionDescription,
      rating: rating ?? this.rating,
    );
  }
}
