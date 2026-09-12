import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
    bool isApplication = false,
  }) async {
    final uid = _currentUid;
    final convRef = _db.collection('conversations').doc(conversationId);

    // Fetch sender's profile so we can store name/photo in the offer
    final senderDoc = await _db.collection('users').doc(uid).get();
    final senderData = senderDoc.data() ?? {};
    final senderName = senderData['fullName'] as String? ?? '';
    final senderPhoto = senderData['photoUrl'] as String? ?? '';

    // Fetch receiver's profile to resolve details for job document
    final receiverDoc = await _db.collection('users').doc(otherUserId).get();
    final receiverData = receiverDoc.data() ?? {};
    final receiverName = receiverData['fullName'] as String? ?? '';
    final receiverPhoto = receiverData['photoUrl'] as String? ?? '';

    String posterId;
    String posterName;
    String posterPhotoUrl;
    String workerId;
    String workerName;
    String workerPhotoUrl;

    if (isApplication) {
      // User is APPLYING to work for otherUserId (who posted the job)
      posterId = otherUserId;
      posterName = receiverName;
      posterPhotoUrl = receiverPhoto;
      workerId = uid;
      workerName = senderName;
      workerPhotoUrl = senderPhoto;
    } else {
      // User is DIRECTLY OFFERING a job to otherUserId (hiring otherUserId)
      posterId = uid;
      posterName = senderName;
      posterPhotoUrl = senderPhoto;
      workerId = otherUserId;
      workerName = receiverName;
      workerPhotoUrl = receiverPhoto;
    }

    final preview = 'Job Offer: $title';

    // Generate references
    final jobRef = _db.collection('jobs').doc();
    final messageRef = convRef.collection('messages').doc();

    final jobOfferData = <String, dynamic>{
      'jobId': jobRef.id,
      'title': title,
      'description': description,
      'price': price,
      'location': location,
      'counterCount': 0,
      'posterId': posterId,
      'posterName': posterName,
      'posterPhotoUrl': posterPhotoUrl,
      'workerId': workerId,
      'workerName': workerName,
      'workerPhotoUrl': workerPhotoUrl,
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

    // Use a WriteBatch to make the writes atomic
    final batch = _db.batch();

    // 1. Add message
    batch.set(messageRef, {
      'senderId': uid,
      'text': preview,
      'messageType': 'job_offer',
      'jobOffer': jobOfferData,
      'sentAt': FieldValue.serverTimestamp(),
    });

    // 2. Create the Offered job post in the /jobs collection
    batch.set(jobRef, {
      'id': jobRef.id,
      'posterId': posterId,
      'posterName': posterName,
      'posterPhotoUrl': posterPhotoUrl,
      'workerId': workerId,
      'workerName': workerName,
      'workerPhotoUrl': workerPhotoUrl,
      'title': title,
      'description': description,
      'price': price,
      'location': location,
      'status': 'offered',
      'counterCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'offeredAt': FieldValue.serverTimestamp(),
      'conversationId': conversationId,
      'messageId': messageRef.id,
      if (scheduledAt != null)
        'scheduledAt': Timestamp.fromDate(scheduledAt),
      ...?jobLatitude == null ? null : {'jobLatitude': jobLatitude},
      ...?jobLongitude == null ? null : {'jobLongitude': jobLongitude},
    });

    // 3. Update conversation metadata
    batch.update(convRef, {
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'unreadCount.$otherUserId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // ─── Accept a job offer → updates /jobs + marks message accepted ──────────
  static Future<void> acceptJobOffer({
    required String conversationId,
    required String messageId,
    required Map<String, dynamic> jobOffer,
  }) async {
    final uid = _currentUid;
    debugPrint('[acceptJobOffer] uid=$uid, conversationId=$conversationId, messageId=$messageId');

    final jobId = jobOffer['jobId'] as String? ?? '';

    // ─── Resolve roles from the /jobs document (source of truth) ────────────
    // NEVER rely on jobOffer['senderUid'] to determine who is the worker or
    // client. The senderUid in the message card changes every time someone
    // counter-offers (it always reflects the LAST person to counter), which
    // causes role swaps if two parties negotiate back and forth.
    // Instead, read posterId/workerId from the actual /jobs document, which
    // are set once at job creation and never change.

    // Fetch the accepting user's profile to resolve their name/photo
    final acceptorDoc = await _db.collection('users').doc(uid).get();
    final acceptorData = acceptorDoc.data() ?? {};
    final acceptorName = acceptorData['fullName'] as String? ?? '';
    final acceptorPhotoUrl = acceptorData['photoUrl'] as String? ?? '';

    String docPosterId = '';
    String docWorkerId = '';
    String docPosterName = '';
    String docPosterPhoto = '';
    String docWorkerName = '';
    String docWorkerPhoto = '';

    if (jobId.isNotEmpty) {
      final jobDoc = await _db.collection('jobs').doc(jobId).get();
      if (jobDoc.exists) {
        final jobData = jobDoc.data()!;
        docPosterId = jobData['posterId'] as String? ?? '';
        docWorkerId = jobData['workerId'] as String? ?? '';
        docPosterName = jobData['posterName'] as String? ?? '';
        docPosterPhoto = jobData['posterPhotoUrl'] as String? ?? '';
        docWorkerName = jobData['workerName'] as String? ?? '';
        docWorkerPhoto = jobData['workerPhotoUrl'] as String? ?? '';
      }
    }

    // Fallback to jobOffer map fields if job doc didn't have them
    if (docPosterId.isEmpty) {
      docPosterId = jobOffer['posterId'] as String? ?? '';
      docPosterName = jobOffer['posterName'] as String? ?? '';
      docPosterPhoto = jobOffer['posterPhotoUrl'] as String? ?? '';
    }
    if (docWorkerId.isEmpty) {
      docWorkerId = jobOffer['workerId'] as String? ?? '';
      docWorkerName = jobOffer['workerName'] as String? ?? '';
      docWorkerPhoto = jobOffer['workerPhotoUrl'] as String? ?? '';
    }

    // Ultimate fallback for legacy cards: infer from conversation
    if (docPosterId.isEmpty || docWorkerId.isEmpty) {
      final convDoc = await _db.collection('conversations').doc(conversationId).get();
      final participantIds = List<String>.from(convDoc.data()?['participantIds'] ?? []);
      final otherId = participantIds.firstWhere((id) => id != uid, orElse: () => '');
      
      final originalOfferSender = jobOffer['senderUid'] as String? ?? '';
      if (docPosterId.isEmpty) {
        docPosterId = originalOfferSender.isNotEmpty ? originalOfferSender : uid;
      }
      if (docWorkerId.isEmpty) {
        docWorkerId = docPosterId == uid ? otherId : uid;
      }
    }

    // 🔒 Canonical assignment: posterId is ALWAYS Client, workerId is ALWAYS Worker.
    // They NEVER swap, regardless of who accepted or who sent the last counter-offer.
    final clientUid = docPosterId;
    final workerUid = docWorkerId;

    String clientName = docPosterName;
    String clientPhoto = docPosterPhoto;
    String workerName = docWorkerName;
    String workerPhoto = docWorkerPhoto;

    if (uid == clientUid) {
      clientName = acceptorName.isNotEmpty ? acceptorName : clientName;
      clientPhoto = acceptorPhotoUrl.isNotEmpty ? acceptorPhotoUrl : clientPhoto;
      if (workerName.isEmpty && workerUid.isNotEmpty) {
        final wDoc = await _db.collection('users').doc(workerUid).get();
        workerName = wDoc.data()?['fullName'] as String? ?? '';
        workerPhoto = wDoc.data()?['photoUrl'] as String? ?? '';
      }
    } else {
      workerName = acceptorName.isNotEmpty ? acceptorName : workerName;
      workerPhoto = acceptorPhotoUrl.isNotEmpty ? acceptorPhotoUrl : workerPhoto;
      if (clientName.isEmpty && clientUid.isNotEmpty) {
        final cDoc = await _db.collection('users').doc(clientUid).get();
        clientName = cDoc.data()?['fullName'] as String? ?? '';
        clientPhoto = cDoc.data()?['photoUrl'] as String? ?? '';
      }
    }

    final scheduledTs = jobOffer['scheduledAt'];
    DateTime? scheduledAt;
    if (scheduledTs is Timestamp) {
      scheduledAt = scheduledTs.toDate();
    } else if (scheduledTs is DateTime) {
      scheduledAt = scheduledTs;
    } else if (scheduledTs is String) {
      scheduledAt = DateTime.tryParse(scheduledTs);
    }

    debugPrint('[acceptJobOffer] resolved workerUid=$workerUid, clientUid=$clientUid');
    debugPrint('[acceptJobOffer] parsed scheduledAt: $scheduledAt, original scheduledTs type: ${scheduledTs.runtimeType}');

    // Check if worker already has another job accepted/active at around this time
    if (scheduledAt != null && workerUid.isNotEmpty) {
      final querySnapshot = await _db
          .collection('jobs')
          .where('workerId', isEqualTo: workerUid)
          .get();

      debugPrint('[acceptJobOffer] Query returned ${querySnapshot.docs.length} jobs for workerId: $workerUid');

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final otherId = doc.id;
        if (jobId.isNotEmpty && otherId == jobId) continue;

        final status = (data['status'] as String? ?? '').toLowerCase();
        debugPrint('[acceptJobOffer] Checking other job $otherId: status=$status, scheduledAt=${data['scheduledAt']}');

        if (status == 'accepted' ||
            status == 'active' ||
            status == 'arrived' ||
            status == 'active_arrived') {
          final otherScheduledTs = data['scheduledAt'];
          DateTime? otherScheduledAt;
          if (otherScheduledTs is Timestamp) {
            otherScheduledAt = otherScheduledTs.toDate();
          } else if (otherScheduledTs is DateTime) {
            otherScheduledAt = otherScheduledTs;
          } else if (otherScheduledTs is String) {
            otherScheduledAt = DateTime.tryParse(otherScheduledTs);
          }

          if (otherScheduledAt != null) {
            final diff = scheduledAt.difference(otherScheduledAt).inMinutes.abs();
            debugPrint('[acceptJobOffer] time difference in minutes: $diff');
            if (diff < 60) {
              final timeStr =
                  '${otherScheduledAt.hour % 12 == 0 ? 12 : otherScheduledAt.hour % 12}:${otherScheduledAt.minute.toString().padLeft(2, '0')} ${otherScheduledAt.hour < 12 ? 'AM' : 'PM'}';
              final errorMsg = (uid == workerUid)
                  ? 'You have already accepted another job at around this time ($timeStr).'
                  : 'This worker has already accepted another job at around this time ($timeStr).';
              throw JobConflictException(errorMsg);
            }
          }
        }
      }
    }

    debugPrint('[acceptJobOffer] jobId=$jobId, posterId=$clientUid, workerUid=$workerUid');

    // Step 1: Update or create the /jobs document
    if (jobId.isNotEmpty) {
      try {
        final updatePayload = <String, dynamic>{
          'posterId': clientUid,
          'posterName': clientName,
          'posterPhotoUrl': clientPhoto,
          'workerId': workerUid,
          'workerName': workerName,
          'workerPhotoUrl': workerPhoto,
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        };
        if (scheduledAt != null) {
          updatePayload['scheduledAt'] = Timestamp.fromDate(scheduledAt);
        }
        if (jobOffer['price'] != null) {
          updatePayload['price'] = (jobOffer['price'] as num).toDouble();
        }
        await _db.collection('jobs').doc(jobId).update(updatePayload);
        debugPrint('[acceptJobOffer] ✅ Step 1 passed: jobs update');
      } catch (e) {
        debugPrint('[acceptJobOffer] ❌ Step 1 FAILED: jobs update → $e');
        throw Exception('Permission denied: cannot update /jobs/$jobId → $e');
      }
    } else {
      // Fallback: create a fresh job doc when offer has no jobId
      try {
        final newJobRef = _db.collection('jobs').doc();
        await newJobRef.set({
          'id': newJobRef.id,
          'posterId': clientUid,
          'posterName': clientName,
          'posterPhotoUrl': clientPhoto,
          'workerId': workerUid,
          'workerName': workerName,
          'workerPhotoUrl': workerPhoto,
          'title': jobOffer['title'] ?? '',
          'description': jobOffer['description'] ?? '',
          'price': (jobOffer['price'] ?? 0.0).toDouble(),
          'location': jobOffer['location'] ?? '',
          'status': 'accepted',
          'createdAt': FieldValue.serverTimestamp(),
          if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt),
          if (jobOffer['jobLatitude'] != null)
            'jobLatitude': (jobOffer['jobLatitude'] as num).toDouble(),
          if (jobOffer['jobLongitude'] != null)
            'jobLongitude': (jobOffer['jobLongitude'] as num).toDouble(),
        });
        debugPrint('[acceptJobOffer] ✅ Step 1 passed: jobs create');
      } catch (e) {
        debugPrint('[acceptJobOffer] ❌ Step 1 FAILED: jobs create → $e');
        throw Exception('Permission denied: cannot create new /jobs document → $e');
      }
    }

    // Step 2: Mark the message as accepted
    try {
      await _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({'jobOffer.status': 'accepted'});
      debugPrint('[acceptJobOffer] ✅ Step 2 passed: message status update');
    } catch (e) {
      debugPrint('[acceptJobOffer] ❌ Step 2 FAILED: message update → $e');
      throw Exception(
          'Permission denied: cannot update message in /conversations/$conversationId/messages/$messageId → $e');
    }
  }


  // ─── Update job offer status (reject only) ────────────────────────────────
  static Future<void> updateJobOfferStatus({
    required String conversationId,
    required String messageId,
    required String status,
    Map<String, dynamic>? jobOffer,
  }) async {
    final batch = _db.batch();

    // Update the message status
    final msgRef = _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);
    batch.update(msgRef, {'jobOffer.status': status});

    // Also update the linked job document if it exists
    if (jobOffer != null) {
      final jobId = jobOffer['jobId'] as String? ?? '';
      if (jobId.isNotEmpty) {
        final jobRef = _db.collection('jobs').doc(jobId);
        batch.update(jobRef, {'status': status});
      }
    }

    await batch.commit();
  }

  // ─── Send a counter-offer ────────────────────────────────────────────────
  static Future<void> sendCounterOffer({
    required String conversationId,
    required String messageId, // previous message being countered
    required String jobId,
    required double counterPrice,
    required DateTime counterScheduledAt,
    required int currentCounterCount,
    required Map<String, dynamic> originalJobOffer,
  }) async {
    if (jobId.trim().isEmpty) {
      throw Exception(
        'Invalid Job ID: The job ID in this offer card is empty. '
        'If this is an old job card, please create a new Job Offer first.',
      );
    }
    try {
      debugPrint('[sendCounterOffer] Starting counter offer flow...');
      debugPrint('  conversationId: $conversationId');
      debugPrint('  messageId (previous): $messageId');
      debugPrint('  jobId: $jobId');
      debugPrint('  counterPrice: $counterPrice');
      debugPrint('  counterScheduledAt: $counterScheduledAt');
      debugPrint('  currentCounterCount: $currentCounterCount');

      final uid = _currentUid;
      final convRef = _db.collection('conversations').doc(conversationId);

      // Fetch the conversation doc to find the other participant dynamically.
      // This is highly robust and avoids relying on potentially missing/corrupted
      // senderUid/receiverUid values in legacy or updated message cards.
      final convDoc = await convRef.get();
      if (!convDoc.exists) {
        throw Exception('Conversation not found: $conversationId');
      }
      final participantIds = List<String>.from(convDoc.data()?['participantIds'] ?? []);
      final receiverUid = participantIds.firstWhere(
        (id) => id != uid,
        orElse: () => '',
      );
      if (receiverUid.isEmpty) {
        throw Exception('Could not find the other participant in the conversation.');
      }

      // Fetch sender's profile so we can store name/photo in the counter offer
      final senderDoc = await _db.collection('users').doc(uid).get();
      final senderData = senderDoc.data() ?? {};
      final senderName = senderData['fullName'] as String? ?? '';
      final senderPhoto = senderData['photoUrl'] as String? ?? '';

      final nextCounterCount = currentCounterCount + 1;
      final title = originalJobOffer['title'] ?? 'Job Offer';
      final description = originalJobOffer['description'] ?? '';
      final location = originalJobOffer['location'] ?? '';
      final jobLatitude = originalJobOffer['jobLatitude'];
      final jobLongitude = originalJobOffer['jobLongitude'];

      debugPrint('  receiverUid: $receiverUid, nextCounterCount: $nextCounterCount');

      final preview = 'Job Counter-Offer: $title';

      // Start a Firestore batch
      final batch = _db.batch();

      // 1. Mark the original message card status to 'countered' so it becomes inactive
      final oldMsgRef = convRef.collection('messages').doc(messageId);
      debugPrint('  Batch 1: marking old message $messageId as countered');
      batch.update(oldMsgRef, {
        'jobOffer.status': 'countered',
      });

      // 2. Create a NEW message card for the counter-offer
      final newMsgRef = convRef.collection('messages').doc();
      final newMsgId = newMsgRef.id;
      debugPrint('  Batch 2: creating new message $newMsgId for counter-offer');

      final posterId = originalJobOffer['posterId'] as String? ?? '';
      final workerId = originalJobOffer['workerId'] as String? ?? '';

      final newJobOfferData = <String, dynamic>{
        'jobId': jobId,
        'title': title,
        'description': description,
        'price': counterPrice,
        'location': location,
        if (posterId.isNotEmpty) 'posterId': posterId,
        if (workerId.isNotEmpty) 'workerId': workerId,
        'senderUid': uid,
        'senderName': senderName,
        'senderPhoto': senderPhoto,
        'receiverUid': receiverUid,
        'scheduledAt': Timestamp.fromDate(counterScheduledAt),
        'counterCount': nextCounterCount,
        'status': null, // pending (action buttons visible to receiver)
      };
      if (jobLatitude != null) newJobOfferData['jobLatitude'] = jobLatitude;
      if (jobLongitude != null) newJobOfferData['jobLongitude'] = jobLongitude;

      batch.set(newMsgRef, {
        'senderId': uid,
        'text': preview,
        'messageType': 'job_offer',
        'jobOffer': newJobOfferData,
        'sentAt': FieldValue.serverTimestamp(),
      });

      // 3. Update job post document in /jobs/{jobId} to point to the new offer details
      // CRITICAL: We do NOT update posterId, posterName, posterPhotoUrl,
      // workerId, workerName, or workerPhotoUrl here. Once a job is created,
      // the client (poster) and worker roles are fixed and should never change.
      // This protects the document from role corruption/same-person bugs.
      final jobRef = _db.collection('jobs').doc(jobId);
      debugPrint('  Batch 3: updating job $jobId details to point to new message $newMsgId');
      batch.update(jobRef, {
        'price': counterPrice,
        'scheduledAt': Timestamp.fromDate(counterScheduledAt),
        'status': 'offered',
        'offeredAt': FieldValue.serverTimestamp(),
        'counterCount': nextCounterCount,
        'messageId': newMsgId, // point to the new counter offer message card
      });

      // 4. Update conversation metadata
      debugPrint('  Batch 4: updating conversation unread count and lastMessage');
      batch.update(convRef, {
        'lastMessage': preview,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': uid,
        'unreadCount.$receiverUid': FieldValue.increment(1),
      });

      debugPrint('[sendCounterOffer] Committing Firestore batch...');
      await batch.commit();
      debugPrint('[sendCounterOffer] ✅ Batch committed successfully!');
    } catch (e, stack) {
      debugPrint('[sendCounterOffer] ❌ ERROR committing batch: $e');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  // ─── Mark conversation as read for current user ───────────────────────────
  static Future<void> markAsRead(String conversationId) async {
    await _db.collection('conversations').doc(conversationId).update({
      'unreadCount.$_currentUid': 0,
    });
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
          debugPrint('Error deleting messages for conversation $id: $e');
        });
      }).catchError((e) {
        debugPrint('Error fetching messages for conversation $id: $e');
      });
    }
  }
}

class JobConflictException implements Exception {
  final String message;
  JobConflictException(this.message);

  @override
  String toString() => message;
}

