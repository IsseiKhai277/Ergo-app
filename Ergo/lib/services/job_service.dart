import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/job_post.dart';

class JobService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of jobs, ordered by newest first
  static Stream<List<JobPost>> get jobsStream {
    return _firestore
        .collection('jobs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JobPost.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Create a new job post
  static Future<void> createJobPost(JobPost job) async {
    await _firestore.collection('jobs').add(job.toMap());
  }
}
