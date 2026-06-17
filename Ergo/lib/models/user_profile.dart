import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user's complete profile document in Firestore.
/// Path: users/{uid}
class UserProfile {
  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String bio;
  final String photoUrl;
  final List<String> skills;
  final String resumeUrl;
  final double rating;
  final int reviewCount;
  final bool verified;
  final bool profileComplete;
  final String role; // 'worker' or 'client'
  final String location;
  final bool showLocation;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phoneNumber = '',
    this.bio = '',
    this.photoUrl = '',
    this.skills = const [],
    this.resumeUrl = '',
    this.rating = 0.0,
    this.reviewCount = 0,
    this.verified = false,
    this.profileComplete = false,
    this.role = 'worker',
    this.location = '',
    this.showLocation = false,
    this.createdAt,
    this.updatedAt,
  });

  // ─── Firestore Deserialization ──────────────────────────────────────────────
  factory UserProfile.fromMap(Map<String, dynamic> map, String uid) {
    return UserProfile(
      uid: uid,
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      photoUrl: map['photoUrl'] as String? ?? '',
      skills: List<String>.from(map['skills'] as List? ?? []),
      resumeUrl: map['resumeUrl'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: map['reviewCount'] as int? ?? 0,
      verified: map['verified'] as bool? ?? false,
      profileComplete: map['profileComplete'] as bool? ?? false,
      role: map['role'] as String? ?? 'worker',
      location: map['location'] as String? ?? '',
      showLocation: map['showLocation'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // ─── Firestore Serialization ────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'bio': bio,
      'photoUrl': photoUrl,
      'skills': skills,
      'resumeUrl': resumeUrl,
      'rating': rating,
      'reviewCount': reviewCount,
      'verified': verified,
      'profileComplete': profileComplete,
      'role': role,
      'location': location,
      'showLocation': showLocation,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ─── Profile Completion ─────────────────────────────────────────────────────
  /// Calculates completion percentage based on filled required fields.
  /// Fields checked: photo, fullName, phoneNumber, skills, resume.
  int get completionPercentage {
    int filled = 0;
    if (photoUrl.isNotEmpty) filled++;
    if (fullName.isNotEmpty) filled++;
    if (phoneNumber.isNotEmpty) filled++;
    if (skills.isNotEmpty) filled++;
    if (resumeUrl.isNotEmpty) filled++;
    return ((filled / 5) * 100).round();
  }

  /// Returns true when all required profile fields are filled.
  bool get isVerified => completionPercentage >= 80;

  // ─── CopyWith ───────────────────────────────────────────────────────────────
  UserProfile copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? bio,
    String? photoUrl,
    List<String>? skills,
    String? resumeUrl,
    double? rating,
    int? reviewCount,
    bool? verified,
    bool? profileComplete,
    String? role,
    String? location,
    bool? showLocation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      skills: skills ?? this.skills,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      verified: verified ?? this.verified,
      profileComplete: profileComplete ?? this.profileComplete,
      role: role ?? this.role,
      location: location ?? this.location,
      showLocation: showLocation ?? this.showLocation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
