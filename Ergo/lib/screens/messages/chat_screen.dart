import 'package:cloud_firestore/cloud_firestore.dart';
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
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textPrimary,
          size: 20,
        ),
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
          icon: const Icon(
            Icons.more_vert_rounded,
            color: AppColors.textSecondary,
          ),
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
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
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
            final showTime =
                i == messages.length - 1 ||
                messages[i + 1].sentAt.difference(msg.sentAt).inMinutes > 10;

            return _MessageBubble(
              message: msg,
              isMe: isMe,
              showTime: showTime,
              conversationId: widget.conversationId,
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
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textHint,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final bool showTime;
  final String conversationId;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showTime,
    required this.conversationId,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _isUpdating = false;

  Future<void> _respond(String status) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      if (status == 'accepted' && widget.message.jobOffer != null) {
        // Creates a /jobs doc AND marks the message accepted
        await ChatService.acceptJobOffer(
          conversationId: widget.conversationId,
          messageId: widget.message.id,
          jobOffer: widget.message.jobOffer!,
        );
      } else {
        // Rejection — just update the message status
        await ChatService.updateJobOfferStatus(
          conversationId: widget.conversationId,
          messageId: widget.message.id,
          status: status,
          jobOffer: widget.message.jobOffer,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${status == 'accepted' ? 'accept' : 'reject'} offer: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: widget.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: widget.isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: widget.isMe ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: widget.isMe
                        ? const Radius.circular(18)
                        : const Radius.circular(4),
                    bottomRight: widget.isMe
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
                child:
                    widget.message.messageType == 'job_offer' &&
                        widget.message.jobOffer != null
                    ? _buildJobOfferCard(context)
                    : Text(
                        widget.message.text,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: widget.isMe
                              ? Colors.white
                              : AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
              ),
            ],
          ),
          if (widget.showTime)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                timeago.format(widget.message.sentAt, allowFromNow: true),
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
    final offer = widget.message.jobOffer!;
    final title = offer['title'] ?? 'Job Offer';
    final description = offer['description'] ?? '';
    final price = offer['price'] ?? 0.0;
    final location = offer['location'] ?? '';
    final status = offer['status'] as String?; // null | 'accepted' | 'rejected'
    final scheduledTs = offer['scheduledAt'];
    DateTime? scheduledAt;
    if (scheduledTs is Timestamp) scheduledAt = scheduledTs.toDate();

    String padTwo(int n) => n.toString().padLeft(2, '0');
    String fmtSchedule(DateTime dt) =>
        '${dt.day}/${dt.month}/${dt.year}  ${padTwo(dt.hour)}:${padTwo(dt.minute)}';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.work_rounded,
                color: widget.isMe ? Colors.white : AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Job Offer',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: widget.isMe ? Colors.white : AppColors.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Title ────────────────────────────────────────
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: widget.isMe ? Colors.white : AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),

          // ── Description ──────────────────────────────────
          Text(
            description,
            style: GoogleFonts.inter(
              color: widget.isMe ? Colors.white70 : AppColors.textSecondary,
              fontSize: 13,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // ── Price ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Colors.white.withOpacity(0.2)
                  : AppColors.accentLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.attach_money_rounded,
                  color: widget.isMe ? Colors.white : AppColors.primary,
                  size: 16,
                ),
                Text(
                  price.toStringAsFixed(2),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: widget.isMe ? Colors.white : AppColors.primary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // ── Location ─────────────────────────────────────
          if (location.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: widget.isMe ? Colors.white70 : AppColors.textHint,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: GoogleFonts.inter(
                      color: widget.isMe ? Colors.white70 : AppColors.textHint,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // ── Schedule ─────────────────────────────────────
          if (scheduledAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: widget.isMe ? Colors.white70 : AppColors.primary,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fmtSchedule(scheduledAt),
                    style: GoogleFonts.inter(
                      color: widget.isMe ? Colors.white70 : AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, color: Colors.white24),
          const SizedBox(height: 12),

          // ── Accept / Reject or Status Badge ──────────────
          _buildActionArea(status),
        ],
      ),
    );
  }

  Widget _buildActionArea(String? status) {
    // If already decided — show status badge (visible to both sides)
    if (status == 'accepted' || status == 'rejected') {
      final isAccepted = status == 'accepted';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isAccepted
              ? const Color(0xFF16A34A).withOpacity(widget.isMe ? 0.25 : 0.12)
              : const Color(0xFFDC2626).withOpacity(widget.isMe ? 0.25 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isAccepted
                ? const Color(0xFF4ADE80).withOpacity(0.5)
                : const Color(0xFFFCA5A5).withOpacity(0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAccepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 16,
              color: isAccepted
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFFFCA5A5),
            ),
            const SizedBox(width: 8),
            Text(
              isAccepted ? 'Accepted' : 'Rejected',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isAccepted
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFFFCA5A5),
              ),
            ),
          ],
        ),
      );
    }

    // Sender sees "Awaiting response" — receiver sees the two action buttons
    if (widget.isMe) {
      return Center(
        child: Text(
          'Awaiting response…',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white60,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Recipient: show Accept / Reject buttons
    return _isUpdating
        ? const Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
          )
        : Row(
            children: [
              // Reject
              Expanded(
                child: GestureDetector(
                  onTap: () => _respond('rejected'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFCA5A5).withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: Color(0xFFFCA5A5),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Reject',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFCA5A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Accept
              Expanded(
                child: GestureDetector(
                  onTap: () => _respond('accepted'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF4ADE80).withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: Color(0xFF4ADE80),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Accept',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4ADE80),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
  }
}
