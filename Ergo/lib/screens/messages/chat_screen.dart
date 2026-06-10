import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../models/conversation_model.dart';
import '../../services/chat_service.dart';
import '../../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhotoUrl;
  final String otherUserRole;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhotoUrl,
    required this.otherUserRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark as read when opening
    ChatService.markAsRead(widget.conversationId);
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    await ChatService.sendMessage(
      conversationId: widget.conversationId,
      text: text,
      otherUserId: widget.otherUserId,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accentLight,
            backgroundImage: widget.otherUserPhotoUrl.isNotEmpty
                ? NetworkImage(widget.otherUserPhotoUrl)
                : null,
            child: widget.otherUserPhotoUrl.isEmpty
                ? Text(
                    widget.otherUserName.isNotEmpty
                        ? widget.otherUserName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.otherUserRole.isNotEmpty)
                  Text(
                    widget.otherUserRole,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call_outlined, color: AppColors.primary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildMessagesList() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<MessageModel>>(
      stream: ChatService.streamMessages(widget.conversationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.waving_hand_rounded,
                  size: 48,
                  color: AppColors.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Say hello to ${widget.otherUserName}!',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final msg = messages[i];
            final isMe = msg.senderId == currentUid;
            final showTime = i == messages.length - 1 ||
                messages[i + 1].sentAt.difference(msg.sentAt).inMinutes > 10;

            return _MessageBubble(
              message: msg,
              isMe: isMe,
              showTime: showTime,
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool showTime;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showTime,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isMe
                        ? const Radius.circular(18)
                        : const Radius.circular(4),
                    bottomRight: isMe
                        ? const Radius.circular(4)
                        : const Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: message.messageType == 'job_offer' && message.jobOffer != null
                    ? _buildJobOfferCard(context)
                    : Text(
                        message.text,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: isMe ? Colors.white : AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
              ),
            ],
          ),
          if (showTime)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                timeago.format(message.sentAt, allowFromNow: true),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppColors.textHint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJobOfferCard(BuildContext context) {
    final offer = message.jobOffer!;
    final title = offer['title'] ?? 'Job Offer';
    final description = offer['description'] ?? '';
    final price = offer['price'] ?? 0.0;
    final location = offer['location'] ?? '';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work_rounded,
                  color: isMe ? Colors.white : AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Job Offer',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: isMe ? Colors.white : AppColors.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: isMe ? Colors.white : AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(
              color: isMe ? Colors.white70 : AppColors.textSecondary,
              fontSize: 13,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isMe ? Colors.white.withOpacity(0.2) : AppColors.accentLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.attach_money_rounded,
                    color: isMe ? Colors.white : AppColors.primary, size: 16),
                Text(
                  price.toStringAsFixed(2),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : AppColors.primary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    color: isMe ? Colors.white70 : AppColors.textHint, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: GoogleFonts.inter(
                      color: isMe ? Colors.white70 : AppColors.textHint,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
