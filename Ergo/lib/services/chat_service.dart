import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/conversation_model.dart';

class ChatService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _currentUid => _auth.currentUser?.uid ?? '';

  // ─── Get or create a conversation between two users ──────────────────────
  static Future<String> getOrCreateConversation(String otherUserId) async {
    final uid = _currentUid;

    // Check if conversation already exists
    final existing = await _db
        .collection('conversations')
        .where('participantIds', arrayContains: uid)
        .get();

    for (final doc in existing.docs) {
      final ids = List<String>.from(doc.data()['participantIds'] ?? []);
      if (ids.contains(otherUserId)) {
        return doc.id;
      }
    }

    // Create a new conversation
    final docRef = _db.collection('conversations').doc();
    await docRef.set({
      'participantIds': [uid, otherUserId],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': '',
      'unreadCount': {uid: 0, otherUserId: 0},
    });

    return docRef.id;
  }

  // ─── Stream all conversations for the current user ───────────────────────
  static Stream<List<ConversationModel>> streamConversations() {
    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: _currentUid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ConversationModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
      return list;
    });
  }

  // ─── Stream the number of conversations with unread messages ──────────────
  static Stream<int> streamUnreadConversationsCount() {
    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: _currentUid)
        .snapshots()
        .map((snap) {
      final uid = _currentUid;
      if (uid.isEmpty) return 0;
      return snap.docs.where((d) {
        final unreadCountMap = Map<String, dynamic>.from(d.data()['unreadCount'] ?? {});
        final count = (unreadCountMap[uid] as num?)?.toInt() ?? 0;
        return count > 0;
      }).length;
    });
  }

  // ─── Stream messages in a conversation ───────────────────────────────────
  static Stream<List<MessageModel>> streamMessages(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MessageModel.fromMap(d.data(), d.id)).toList());
  }

  // ─── Send a message ───────────────────────────────────────────────────────
  static Future<void> sendMessage({
    required String conversationId,
    required String text,
    required String otherUserId,
  }) async {
    if (text.trim().isEmpty) return;
    final uid = _currentUid;
    final convRef = _db.collection('conversations').doc(conversationId);

    // Add message
    await convRef.collection('messages').add({
      'senderId': uid,
      'text': text.trim(),
      'sentAt': FieldValue.serverTimestamp(),
    });

    // Update conversation metadata
    await convRef.update({
      'lastMessage': text.trim(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'unreadCount.$otherUserId': FieldValue.increment(1),
    });
  }

  // ─── Send a job offer as a special message ───────────────────────────────
  static Future<void> sendJobOffer({
    required String conversationId,
    required String otherUserId,
    required String title,
    required String description,
    required double price,
    required String location,
    DateTime? scheduledAt,
    double? jobLatitude,
    double? jobLongitude,
  }) async {
    final uid = _currentUid;
    final convRef = _db.collection('conversations').doc(conversationId);

    // Fetch sender's profile so we can store name/photo in the offer
    final senderDoc = await _db.collection('users').doc(uid).get();
    final senderName = senderDoc.data()?['fullName'] as String? ?? '';
    final senderPhoto = senderDoc.data()?['photoUrl'] as String? ?? '';

    final preview = 'Job Offer: $title';

    // Generate job document ID beforehand
    final jobRef = _db.collection('jobs').doc();

    final jobOfferData = <String, dynamic>{
      'jobId': jobRef.id,
      'title': title,
      'description': description,
      'price': price,
      'location': location,
      // Store both parties so we can write a proper jobs doc on accept
      'senderUid': uid,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'receiverUid': otherUserId,
    };
    if (scheduledAt != null) {
      jobOfferData['scheduledAt'] = Timestamp.fromDate(scheduledAt);
    }
    if (jobLatitude != null) jobOfferData['jobLatitude'] = jobLatitude;
    if (jobLongitude != null) jobOfferData['jobLongitude'] = jobLongitude;

    final messageRef = await convRef.collection('messages').add({
      'senderId': uid,
      'text': preview,
      'messageType': 'job_offer',
      'jobOffer': jobOfferData,
      'sentAt': FieldValue.serverTimestamp(),
    });

    // Create the Offered job post in the /jobs collection
    await jobRef.set({
      'id': jobRef.id,
      'posterId': uid,
      'posterName': senderName,
      'posterPhotoUrl': senderPhoto,
      'workerId': otherUserId,
      'workerName': '',
      'workerPhotoUrl': '',
      'title': title,
      'description': description,
      'price': price,
      'location': location,
      'status': 'offered',
      'createdAt': FieldValue.serverTimestamp(),
      'conversationId': conversationId,
      'messageId': messageRef.id,
      if (scheduledAt != null)
        'scheduledAt': Timestamp.fromDate(scheduledAt),
      if (jobLatitude != null) 'jobLatitude': jobLatitude,
      if (jobLongitude != null) 'jobLongitude': jobLongitude,
    });

    await convRef.update({
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'unreadCount.$otherUserId': FieldValue.increment(1),
    });
  }

  // ─── Accept a job offer → creates a real doc in /jobs ────────────────────
  /// Call this instead of (or in addition to) updateJobOfferStatus when the
  /// recipient taps Accept. It writes a proper JobPost document so the job
  /// shows up on both parties' My Jobs screens.
  static Future<void> acceptJobOffer({
    required String conversationId,
    required String messageId,
    required Map<String, dynamic> jobOffer,
  }) async {
    final uid = _currentUid;

    // Fetch the accepting user's profile for worker name/photo
    final workerDoc = await _db.collection('users').doc(uid).get();
    final workerName = workerDoc.data()?['fullName'] as String? ?? '';
    final workerPhoto = workerDoc.data()?['photoUrl'] as String? ?? '';

    final posterId = jobOffer['senderUid'] as String? ?? '';
    final posterName = jobOffer['senderName'] as String? ?? '';
    final posterPhoto = jobOffer['senderPhoto'] as String? ?? '';

    final scheduledTs = jobOffer['scheduledAt'];
    final scheduledAt =
        scheduledTs is Timestamp ? scheduledTs.toDate() : null;

    final jobId = jobOffer['jobId'] as String? ?? '';
    if (jobId.isNotEmpty) {
      // Update the existing Offered job document in /jobs to Accepted
      await _db.collection('jobs').doc(jobId).update({
        'workerName': workerName,
        'workerPhotoUrl': workerPhoto,
        'status': 'accepted',
      });
    } else {
      // Fallback for legacy offers that do not have a jobId field
      await _db.collection('jobs').add({
        'posterId': posterId,
        'posterName': posterName,
        'posterPhotoUrl': posterPhoto,
        'workerId': uid,
        'workerName': workerName,
        'workerPhotoUrl': workerPhoto,
        'title': jobOffer['title'] ?? '',
        'description': jobOffer['description'] ?? '',
        'price': (jobOffer['price'] ?? 0.0).toDouble(),
        'location': jobOffer['location'] ?? '',
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
        if (scheduledAt != null)
          'scheduledAt': Timestamp.fromDate(scheduledAt),
        if (jobOffer['jobLatitude'] != null)
          'jobLatitude': (jobOffer['jobLatitude'] as num).toDouble(),
        if (jobOffer['jobLongitude'] != null)
          'jobLongitude': (jobOffer['jobLongitude'] as num).toDouble(),
      });
    }

    // 2. Mark the message as accepted
    await updateJobOfferStatus(
      conversationId: conversationId,
      messageId: messageId,
      status: 'accepted',
      jobOffer: jobOffer,
    );
  }

  // ─── Mark conversation as read for current user ───────────────────────────
  static Future<void> markAsRead(String conversationId) async {
    await _db.collection('conversations').doc(conversationId).update({
      'unreadCount.$_currentUid': 0,
    });
  }

  // ─── Update job offer status (accept / reject) ────────────────────────────
  static Future<void> updateJobOfferStatus({
    required String conversationId,
    required String messageId,
    required String status, // 'accepted' | 'rejected'
    Map<String, dynamic>? jobOffer,
  }) async {
    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'jobOffer.status': status});

    if (jobOffer != null) {
      final jobId = jobOffer['jobId'] as String? ?? '';
      if (jobId.isNotEmpty) {
        await _db.collection('jobs').doc(jobId).update({
          'status': status,
        });
      }
    }
  }

  // ─── Get other participant's ID from a conversation ───────────────────────
  static String getOtherUserId(ConversationModel convo) {
    return convo.participantIds.firstWhere(
      (id) => id != _currentUid,
      orElse: () => '',
    );
  }

  // ─── Delete conversations (deletes conversation documents and clean up subcollection messages in background) ───
  static Future<void> deleteConversations(List<String> conversationIds) async {
    final batch = _db.batch();
    for (final id in conversationIds) {
      batch.delete(_db.collection('conversations').doc(id));
    }
    await batch.commit();

    // Clean up messages in the background asynchronously
    for (final id in conversationIds) {
      _db
          .collection('conversations')
          .doc(id)
          .collection('messages')
          .get()
          .then((snap) {
        final innerBatch = _db.batch();
        for (final doc in snap.docs) {
          innerBatch.delete(doc.reference);
        }
        innerBatch.commit().catchError((e) {
          // Silent catch or debug print
          print('Error deleting messages for conversation $id: $e');
        });
      }).catchError((e) {
        print('Error fetching messages for conversation $id: $e');
      });
    }
  }
}

