import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/job_post.dart';

class JobService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _currentUid => _auth.currentUser?.uid ?? '';

  // ─── All jobs (browse feed), newest first ──────────────────────────────────
  static Stream<List<JobPost>> get jobsStream {
    return _firestore
        .collection('jobs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JobPost.fromMap(doc.data(), doc.id))
            .toList());
  }

  // ─── Jobs where current user is the worker (applied / accepted) ────────────
  static Stream<List<JobPost>> get myWorkerJobsStream {
    return _firestore
        .collection('jobs')
        .where('workerId', isEqualTo: _currentUid)
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map((doc) => JobPost.fromMap(doc.data(), doc.id))
              .toList();
          jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return jobs;
        });
  }

  // ─── Jobs posted by the current user (client view) ────────────────────────
  static Stream<List<JobPost>> get myPostedJobsStream {
    return _firestore
        .collection('jobs')
        .where('posterId', isEqualTo: _currentUid)
        .snapshots()
        .map((snapshot) {
          final jobs = snapshot.docs
              .map((doc) => JobPost.fromMap(doc.data(), doc.id))
              .toList();
          jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return jobs;
        });
  }

  // ─── Worker/Client stats ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getJobStats(String role) async {
    final uid = _currentUid;
    final snap = role == 'client'
        ? await _firestore
            .collection('jobs')
            .where('posterId', isEqualTo: uid)
            .get()
        : await _firestore
            .collection('jobs')
            .where('workerId', isEqualTo: uid)
            .get();

    int active = 0;
    int completed = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final status = data['status'] as String? ?? 'active';
      if (status == 'completed') {
        completed++;
      } else if (status == 'active' ||
          status == 'accepted' ||
          status == 'arrived' ||
          status == 'active_arrived') {
        active++;
      }
    }

    // Always calculate worker-side earnings (jobs where current user is worker and status is completed)
    double totalEarnings = 0.0;
    if (uid.isNotEmpty) {
      final workerCompletedSnap = await _firestore
          .collection('jobs')
          .where('workerId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .get();

      for (final doc in workerCompletedSnap.docs) {
        final data = doc.data();
        final price = (data['price'] ?? 0.0).toDouble();
        totalEarnings += price;
      }
    }

    return {
      'active': active,
      'completed': completed,
      'totalEarnings': totalEarnings,
    };
  }

  // ─── Update job status ─────────────────────────────────────────────────────
  static Future<void> updateJobStatus(String jobId, String status) async {
    await _firestore.collection('jobs').doc(jobId).update({'status': status});
  }

  // ─── Auto-reject an expired job offer ─────────────────────────────────────
  /// Called client-side when the 30-minute offer window elapses.
  static Future<void> rejectExpiredOffer(String jobId) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'status': 'rejected',
      'expiredAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Complete job and rate worker ──────────────────────────────────────────
  static Future<void> completeJob({
    required String jobId,
    required String workerId,
    required File imageFile,
    required String comment,
    required double rating,
  }) async {
    final clientUid = _currentUid;
    if (clientUid.isEmpty) {
      throw Exception('User is not authenticated');
    }

    // 1. Upload file to Firebase Storage under the client\'s UID directory to satisfy security rules
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('posts')
        .child(clientUid)
        .child(jobId)
        .child('completion_photo.jpg');
    final uploadTask = await storageRef.putFile(imageFile);
    final downloadUrl = await uploadTask.ref.getDownloadURL();

    // 2. Update the job document status and review info
    await _firestore.collection('jobs').doc(jobId).update({
      'status': 'completed',
      'completionPhoto': downloadUrl,
      'completionDescription': comment,
      'rating': rating,
    });

    // 3. Add review document to the reviews collection (allowed for client)
    if (workerId.isNotEmpty) {
      final clientUid = _currentUid;
      String reviewerName = 'Client';
      String reviewerPhotoUrl = '';
      if (clientUid.isNotEmpty) {
        final clientDoc = await _firestore.collection('users').doc(clientUid).get();
        if (clientDoc.exists) {
          final data = clientDoc.data()!;
          reviewerName = data['fullName'] ?? data['name'] ?? 'Client';
          reviewerPhotoUrl = data['photoUrl'] ?? data['photoURL'] ?? '';
        }
      }

      await _firestore.collection('reviews').add({
        'userId': workerId,
        'reviewerName': reviewerName,
        'reviewerPhotoUrl': reviewerPhotoUrl,
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Recalculate average rating and update worker profile
      final reviewsSnap = await _firestore
          .collection('reviews')
          .where('userId', isEqualTo: workerId)
          .get();

      final totalRating = reviewsSnap.docs.fold<double>(
        0.0,
        (acc, doc) => acc + ((doc.data()['rating'] as num?)?.toDouble() ?? 0.0),
      );
      final averageRating = reviewsSnap.docs.isEmpty ? 0.0 : totalRating / reviewsSnap.docs.length;

      await _firestore.collection('users').doc(workerId).update({
        'rating': averageRating,
        'reviewCount': reviewsSnap.docs.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 5. Automatically create a feed post representing the completed project
      final postRef = _firestore.collection('posts').doc();
      await postRef.set({
        'postId': postRef.id,
        'userId': workerId, // Worker is the subject of the post
        'clientId': clientUid, // Client who completed it
        'jobId': jobId, // Store jobId to locate the photo in storage on deletion
        'caption': comment.trim(),
        'imageUrls': [downloadUrl],
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
      });
    }
  }

  // ─── Save job location (set by client when posting / offering) ────────────
  static Future<void> saveJobLocation(
    String jobId,
    double latitude,
    double longitude,
  ) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'jobLatitude': latitude,
      'jobLongitude': longitude,
    });
  }

  // ─── Remove worker live-tracking fields (called on Arrived) ───────────────
  static Future<void> clearWorkerLocation(String jobId) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'workerLatitude': FieldValue.delete(),
      'workerLongitude': FieldValue.delete(),
      'workerLastUpdated': FieldValue.delete(),
    });
  }

  // ─── Stream of the worker's currently active job ──────────────────────────
  /// Used by [ActiveJobProvider] to show the global "Back to Job" FAB.
  static Stream<JobPost?> get activeWorkerJobStream {
    final uid = _currentUid;
    if (uid.isEmpty) return Stream.value(null);
    return _firestore
        .collection('jobs')
        .where('workerId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          for (final doc in snap.docs) {
            final job = JobPost.fromMap(doc.data(), doc.id);
            if (job.status == 'active' ||
                job.status == 'arrived' ||
                job.status == 'active_arrived') {
              return job;
            }
          }
          return null;
        });
  }

  // ─── Stream of the client's currently active or completed job ─────────────
  /// Used to show the global "On Job" blue FAB on the client side, or trigger
  /// an "arrived" popup.
  static Stream<JobPost?> get activeClientJobStream {
    final uid = _currentUid;
    if (uid.isEmpty) return Stream.value(null);
    return _firestore
        .collection('jobs')
        .where('posterId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          for (final doc in snap.docs) {
            final job = JobPost.fromMap(doc.data(), doc.id);
            if (job.status == 'active' ||
                job.status == 'arrived' ||
                job.status == 'active_arrived') {
              return job;
            }
          }
          return null;
        });
  }

  // ─── Create a new job post ─────────────────────────────────────────────────
  static Future<void> createJobPost(JobPost job) async {
    await _firestore.collection('jobs').add(job.toMap());
  }
}
