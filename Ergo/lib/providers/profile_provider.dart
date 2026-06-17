import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../models/review.dart';
import '../services/profile_service.dart';
import '../services/resume_ai_service.dart';

/// State management for the Profile module using Provider (ChangeNotifier).
///
/// Holds the current user's profile, reviews, and all loading/error states.
/// All UI widgets listen to this provider for reactive updates.
class ProfileProvider extends ChangeNotifier {
  UserProfile? _profile;
  List<Review> _reviews = [];
  bool _isLoading = false;
  bool _isUpdating = false;
  bool _isUploadingImage = false;
  bool _isUploadingResume = false;
  String? _errorMessage;

  // ─── Getters ───────────────────────────────────────────────────────────────
  UserProfile? get profile => _profile;
  List<Review> get reviews => _reviews;
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  bool get isUploadingImage => _isUploadingImage;
  bool get isUploadingResume => _isUploadingResume;
  String? get errorMessage => _errorMessage;

  // ─── Initialize / Subscribe ────────────────────────────────────────────────
  /// Call once when the Profile tab is first opened.
  /// Subscribes to real-time profile and reviews streams.
  void init() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    // Subscribe to profile changes
    ProfileService.profileStream(uid).listen(
      (profile) {
        _profile = profile;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
        _syncRatingIfNeeded();
      },
      onError: (e) {
        _errorMessage = 'Failed to load profile: $e';
        _isLoading = false;
        notifyListeners();
      },
    );

    // Subscribe to reviews
    ProfileService.reviewsStream(uid).listen(
      (reviews) {
        _reviews = reviews;
        notifyListeners();
        _syncRatingIfNeeded();
      },
      onError: (e) {
        debugPrint('Reviews stream error: $e');
      },
    );
  }

  /// Recalculates worker's average rating and count and updates their user document
  /// if they don't match. This runs under the worker's own permission.
  Future<void> _syncRatingIfNeeded() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final currentProfile = _profile;
    if (uid == null || currentProfile == null) return;

    int count = _reviews.length;
    double total = _reviews.fold<double>(0.0, (acc, r) => acc + r.rating);
    double average = count == 0 ? 0.0 : total / count;

    final double profileRating = currentProfile.rating;
    final int profileReviewCount = currentProfile.reviewCount;

    // Allow minor float differences within 0.01 precision
    if ((profileRating - average).abs() > 0.01 || profileReviewCount != count) {
      debugPrint('Syncing profile rating for $uid: current=$profileRating, calculated=$average, count=$count');
      try {
        await ProfileService.updateProfile(
          uid: uid,
          data: {
            'rating': average,
            'reviewCount': count,
          },
        );
      } catch (e) {
        debugPrint('Failed to sync profile rating: $e');
      }
    }
  }

  // ─── Update Profile ────────────────────────────────────────────────────────
  Future<bool> updateProfile({
    required String fullName,
    required String phoneNumber,
    required String bio,
    String location = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ProfileService.updateProfile(
        uid: uid,
        data: {
          'fullName': fullName.trim(),
          'phoneNumber': phoneNumber.trim(),
          'bio': bio.trim(),
          'location': location.trim(),
        },
      );

      // Also update Firebase Auth display name
      await FirebaseAuth.instance.currentUser
          ?.updateDisplayName(fullName.trim());

      _isUpdating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile: $e';
      _isUpdating = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Update Show Location Setting ──────────────────────────────────────────
  Future<bool> updateShowLocation(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      await ProfileService.updateProfile(
        uid: uid,
        data: {
          'showLocation': value,
        },
      );
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update location visibility: $e';
      notifyListeners();
      return false;
    }
  }

  // ─── Upload Profile Image ──────────────────────────────────────────────────
  Future<bool> uploadProfileImage(File imageFile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    _isUploadingImage = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Upload to Storage
      final imageUrl = await ProfileService.uploadProfileImage(
        uid: uid,
        imageFile: imageFile,
      );

      // Save URL to Firestore + Firebase Auth
      await ProfileService.saveProfileImageUrl(uid: uid, imageUrl: imageUrl);

      _isUploadingImage = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to upload image: $e';
      _isUploadingImage = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Update Skills ─────────────────────────────────────────────────────────
  Future<void> addSkill(String skill) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _profile == null) return;

    final trimmed = skill.trim();
    if (trimmed.isEmpty) return;

    // Prevent duplicates (case-insensitive)
    final existing = _profile!.skills.map((s) => s.toLowerCase()).toList();
    if (existing.contains(trimmed.toLowerCase())) return;

    final updatedSkills = [..._profile!.skills, trimmed];
    await ProfileService.updateSkills(uid: uid, skills: updatedSkills);
  }

  Future<void> removeSkill(String skill) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _profile == null) return;

    final updatedSkills =
        _profile!.skills.where((s) => s != skill).toList();
    await ProfileService.updateSkills(uid: uid, skills: updatedSkills);
  }

  Future<void> saveSkills(List<String> skills) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await ProfileService.updateSkills(uid: uid, skills: skills);
  }

  // ─── Upload Resume & Extract AI Skills ────────────────────────────────────
  Future<List<String>> uploadResumeAndExtractSkills({
    required File resumeFile,
    required String fileName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    _isUploadingResume = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Upload resume file to Firebase Storage
      final resumeUrl = await ProfileService.uploadResume(
        uid: uid,
        resumeFile: resumeFile,
        fileName: fileName,
      );

      // 2. Save resume URL to Firestore
      await ProfileService.saveResumeUrl(uid: uid, resumeUrl: resumeUrl);

      // 3. Extract skills via AI service (currently mock)
      final skills = await ResumeAIService.extractSkills(resumeUrl: resumeUrl);

      _isUploadingResume = false;
      notifyListeners();
      return skills;
    } catch (e) {
      _errorMessage = 'Failed to process resume: $e';
      _isUploadingResume = false;
      notifyListeners();
      return [];
    }
  }

  // ─── Upload Resume Only ───────────────────────────────────────────────────
  Future<bool> uploadResumeOnly({
    required File resumeFile,
    required String fileName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    _isUploadingResume = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Upload resume file to Firebase Storage
      final resumeUrl = await ProfileService.uploadResume(
        uid: uid,
        resumeFile: resumeFile,
        fileName: fileName,
      );

      // 2. Save resume URL to Firestore
      await ProfileService.saveResumeUrl(uid: uid, resumeUrl: resumeUrl);

      _isUploadingResume = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to upload resume: $e';
      _isUploadingResume = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Extract Skills From Uploaded Resume ──────────────────────────────────
  Future<List<String>> extractSkillsFromUploadedResume() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final resumeUrl = _profile?.resumeUrl;
    if (uid == null || resumeUrl == null || resumeUrl.isEmpty) return [];

    _isUploadingResume = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final skills = await ResumeAIService.extractSkills(resumeUrl: resumeUrl);

      _isUploadingResume = false;
      notifyListeners();
      return skills;
    } catch (e) {
      _errorMessage = 'Failed to extract skills: $e';
      _isUploadingResume = false;
      notifyListeners();
      return [];
    }
  }

  // ─── Clear Error ───────────────────────────────────────────────────────────
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
