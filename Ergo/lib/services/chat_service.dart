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
  }) async {
    final uid = _currentUid;
    final convRef = _db.collection('conversations').doc(conversationId);

    final preview = 'Job Offer: $title';

    await convRef.collection('messages').add({
      'senderId': uid,
      'text': preview,
      'messageType': 'job_offer',
      'jobOffer': {
        'title': title,
        'description': description,
        'price': price,
        'location': location,
      },
      'sentAt': FieldValue.serverTimestamp(),
    });

    await convRef.update({
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'unreadCount.$otherUserId': FieldValue.increment(1),
    });
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
}
