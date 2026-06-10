import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final List<String> participantIds;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastSenderId;
  final Map<String, int> unreadCount; // userId -> unread count

  ConversationModel({
    required this.id,
    required this.participantIds,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderId,
    required this.unreadCount,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> data, String docId) {
    return ConversationModel(
      id: docId,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageAt:
          (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSenderId: data['lastSenderId'] ?? '',
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
    );
  }
}

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final String messageType; // 'normal' | 'job_offer'
  final Map<String, dynamic>? jobOffer; // title, description, price, location

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.messageType = 'normal',
    this.jobOffer,
  });

  factory MessageModel.fromMap(Map<String, dynamic> data, String docId) {
    return MessageModel(
      id: docId,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      messageType: data['messageType'] ?? 'normal',
      jobOffer: data['jobOffer'] != null
          ? Map<String, dynamic>.from(data['jobOffer'])
          : null,
    );
  }
}

