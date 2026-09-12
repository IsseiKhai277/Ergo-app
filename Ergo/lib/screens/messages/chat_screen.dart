import 'dart:async';
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
  bool _isOtherUserVerified = false;

  @override
  void initState() {
    super.initState();
    ChatService.markAsRead(widget.conversationId);
    _fetchOtherUserProfile();
  }

  Future<void> _fetchOtherUserProfile() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).get();
      if (doc.exists && mounted) {
        setState(() {
          _isOtherUserVerified = doc.data()?['verified'] == true;
        });
      }
    } catch (_) {}
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.otherUserName,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.otherUserRole.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _isOtherUserVerified
                              ? const Color(0xFF10B981)
                              : const Color(0xFF64748B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _isOtherUserVerified
                              ? widget.otherUserRole.toUpperCase()
                              : 'UNVERIFIED',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
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
                  color: AppColors.primary.withValues(alpha: 0.5),
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

  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  bool _isExpired = false;
  bool _hasTriggeredRejection = false;

  @override
  void initState() {
    super.initState();
    _startCountdownIfPending();
  }

  @override
  void didUpdateWidget(_MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.jobOffer?['status'] !=
            widget.message.jobOffer?['status'] ||
        oldWidget.message.sentAt != widget.message.sentAt) {
      _countdownTimer?.cancel();
      _startCountdownIfPending();
    }
  }

  void _startCountdownIfPending() {
    if (widget.message.messageType != 'job_offer' ||
        widget.message.jobOffer == null) {
      return;
    }
    final status = widget.message.jobOffer!['status'] as String?;
    if (status == 'accepted' || status == 'rejected' || status == 'countered') return;

    final sentAt = widget.message.sentAt;

    void tick() {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(sentAt);
      final remaining = const Duration(minutes: 30) - elapsed;
      if (remaining.isNegative || remaining == Duration.zero) {
        setState(() {
          _remaining = Duration.zero;
          _isExpired = true;
        });
        _countdownTimer?.cancel();
        if (!widget.isMe && !_hasTriggeredRejection) {
          _hasTriggeredRejection = true;
          _respond('rejected');
        }
      } else {
        setState(() {
          _remaining = remaining;
          _isExpired = false;
        });
      }
    }

    // Schedule tick after build to avoid setState-during-build errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        tick();
      }
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  String get _countdownLabel {
    if (_isExpired) return 'Expired';
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

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
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text('Failed to ${status == 'accepted' ? 'Accept' : 'Reject'} Offer'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('OK'),
              ),
            ],
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
                      color: Colors.black.withValues(alpha: 0.04),
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

    final counterCount = (offer['counterCount'] as num?)?.toInt() ?? 0;

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
                counterCount > 0 ? Icons.sync_alt_rounded : Icons.work_rounded,
                color: widget.isMe ? Colors.white : AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                counterCount > 0 ? 'Counter Offer ($counterCount/3)' : 'Job Offer',
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
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.accentLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'RM ${price.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: widget.isMe ? Colors.white : AppColors.primary,
                fontSize: 14,
              ),
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
    if (status == 'accepted' || status == 'rejected' || status == 'countered') {
      final isAccepted = status == 'accepted';
      final isRejected = status == 'rejected';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isAccepted
              ? const Color(0xFF16A34A).withValues(alpha: widget.isMe ? 0.25 : 0.12)
              : isRejected
                  ? const Color(0xFFDC2626).withValues(alpha: widget.isMe ? 0.25 : 0.12)
                  : const Color(0xFF475569).withValues(alpha: widget.isMe ? 0.25 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isAccepted
                ? const Color(0xFF4ADE80).withValues(alpha: 0.5)
                : isRejected
                    ? const Color(0xFFFCA5A5).withValues(alpha: 0.5)
                    : const Color(0xFF94A3B8).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAccepted
                  ? Icons.check_circle_rounded
                  : isRejected
                      ? Icons.cancel_rounded
                      : Icons.sync_rounded,
              size: 16,
              color: isAccepted
                  ? const Color(0xFF4ADE80)
                  : isRejected
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Text(
              isAccepted
                  ? 'Accepted'
                  : isRejected
                      ? 'Rejected'
                      : 'Countered',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isAccepted
                    ? const Color(0xFF4ADE80)
                    : isRejected
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    // Sender sees "Awaiting response" — receiver sees the two/three action buttons
    if (widget.isMe) {
      return Center(
        child: Text(
          _isExpired ? 'Offer expired' : 'Awaiting response…',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white60,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    // Recipient: show Accept / Reject / Counter buttons
    final offer = widget.message.jobOffer!;
    final counterCount = offer['counterCount'] as int? ?? 0;
    final showCounter = counterCount < 3;

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
        : Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isExpired ? Icons.timer_off_rounded : Icons.timer_rounded,
                    size: 14,
                    color: _isExpired
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF4ADE80),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isExpired
                        ? 'Offer has expired'
                        : 'Expires in $_countdownLabel',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isExpired
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF4ADE80),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (showCounter) ...[
                // Counter Offer Button
                GestureDetector(
                  onTap: _isExpired ? null : () => _showCounterOfferSheet(context, offer),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: _isExpired ? 0.05 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: _isExpired ? 0.2 : 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sync_alt_rounded,
                          size: 15,
                          color: AppColors.primary.withValues(alpha: _isExpired ? 0.5 : 1.0),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Counter Offer',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary.withValues(alpha: _isExpired ? 0.5 : 1.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  // Reject
                  Expanded(
                    child: GestureDetector(
                      onTap: _isExpired ? null : () => _respond('rejected'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFDC2626,
                          ).withValues(alpha: _isExpired ? 0.05 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(
                              0xFFFCA5A5,
                            ).withValues(alpha: _isExpired ? 0.2 : 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 15,
                              color: const Color(
                                0xFFFCA5A5,
                              ).withValues(alpha: _isExpired ? 0.5 : 1.0),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Reject',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(
                                  0xFFFCA5A5,
                                ).withValues(alpha: _isExpired ? 0.5 : 1.0),
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
                      onTap: _isExpired ? null : () => _respond('accepted'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF16A34A,
                          ).withValues(alpha: _isExpired ? 0.05 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(
                              0xFF4ADE80,
                            ).withValues(alpha: _isExpired ? 0.2 : 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: const Color(
                                0xFF4ADE80,
                               ).withValues(alpha: _isExpired ? 0.5 : 1.0),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Accept',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(
                                  0xFF4ADE80,
                                ).withValues(alpha: _isExpired ? 0.5 : 1.0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
  }

  void _showCounterOfferSheet(BuildContext context, Map<String, dynamic> offer) {
    // Safely parse initial price to handle both double and String formats
    double initialPrice = 0.0;
    if (offer['price'] is num) {
      initialPrice = (offer['price'] as num).toDouble();
    } else if (offer['price'] is String) {
      initialPrice = double.tryParse(offer['price'] as String) ?? 0.0;
    }
    final priceController = TextEditingController(text: initialPrice.toStringAsFixed(2));

    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    final scheduledTs = offer['scheduledAt'];
    if (scheduledTs is Timestamp) {
      final dt = scheduledTs.toDate();
      selectedDate = dt;
      selectedTime = TimeOfDay.fromDateTime(dt);
    } else {
      // Fallback: pre-populate with current time to avoid validation errors if timestamp is missing
      final now = DateTime.now();
      selectedDate = now;
      selectedTime = TimeOfDay.fromDateTime(now);
    }

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> pickDate() async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: ctx,
              initialDate: selectedDate ?? now,
              firstDate: now,
              lastDate: now.add(const Duration(days: 365)),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.surface,
                    onSurface: AppColors.textPrimary,
                  ),
                  dialogBackgroundColor: AppColors.background,
                ),
                child: child!,
              ),
            );
            if (picked != null) setSheetState(() => selectedDate = picked);
          }

          Future<void> pickTime() async {
            final picked = await showTimePicker(
              context: ctx,
              initialTime: selectedTime ?? TimeOfDay.now(),
              builder: (c, child) => Theme(
                data: Theme.of(c).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.surface,
                    onSurface: AppColors.textPrimary,
                  ),
                  dialogBackgroundColor: AppColors.background,
                ),
                child: child!,
              ),
            );
            if (picked != null) setSheetState(() => selectedTime = picked);
          }

          return Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Make a Counter Offer',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Suggest changes to payment, date, or time.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                // Price input
                Text(
                  'Counter Price (RM)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.attach_money_rounded, color: AppColors.textHint, size: 20),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Date & Time pickers
                Text(
                  'Counter Schedule',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedDate != null
                                      ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                                      : 'Pick date',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: selectedDate != null ? AppColors.textPrimary : AppColors.textHint,
                                    fontWeight: selectedDate != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: pickTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedTime != null ? selectedTime!.format(ctx) : 'Pick time',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: selectedTime != null ? AppColors.textPrimary : AppColors.textHint,
                                    fontWeight: selectedTime != null ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final price = double.tryParse(priceController.text) ?? 0.0;
                            if (price <= 0) {
                              showDialog(
                                context: ctx,
                                builder: (c) => AlertDialog(
                                  title: const Text('Validation Error'),
                                  content: const Text('Please enter a valid price.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }
                            if (selectedDate == null || selectedTime == null) {
                              showDialog(
                                context: ctx,
                                builder: (c) => AlertDialog(
                                  title: const Text('Validation Error'),
                                  content: const Text('Please pick a counter schedule date and time.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }

                            setSheetState(() => isSubmitting = true);

                            try {
                              final counterScheduledAt = DateTime(
                                selectedDate!.year,
                                selectedDate!.month,
                                selectedDate!.day,
                                selectedTime!.hour,
                                selectedTime!.minute,
                              );

                              await ChatService.sendCounterOffer(
                                conversationId: widget.conversationId,
                                messageId: widget.message.id,
                                jobId: offer['jobId'] ?? '',
                                counterPrice: price,
                                counterScheduledAt: counterScheduledAt,
                                currentCounterCount: (offer['counterCount'] as num?)?.toInt() ?? 0,
                                originalJobOffer: offer,
                              );

                              if (ctx.mounted) {
                                Navigator.pop(ctx); // Close sheet ONLY on success
                              }

                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Success'),
                                    content: const Text('Counter offer sent successfully to the database!'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isSubmitting = false);
                              if (ctx.mounted) {
                                showDialog(
                                  context: ctx, // Show error dialog on top of the sheet
                                  builder: (c) => AlertDialog(
                                    title: const Text('Counter Offer Error'),
                                    content: Text(e.toString()),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isUpdating = false);
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Submit Counter Offer',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
