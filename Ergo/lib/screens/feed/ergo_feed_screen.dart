import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../theme/app_theme.dart';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../services/feed_post_service.dart';
import '../../services/feed_comment_service.dart';
import '../../services/feed_user_resolver_service.dart';
import '../profile/user_profile_screen.dart';

class ErgoFeedScreen extends StatefulWidget {
  const ErgoFeedScreen({super.key});

  @override
  State<ErgoFeedScreen> createState() => _ErgoFeedScreenState();
}

class _ErgoFeedScreenState extends State<ErgoFeedScreen> {
  final TextEditingController _captionController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isPosting = false;
  String _selectedCategory = 'All Posts';

  final List<String> _categories = [
    'All Posts',
    'Electrician',
    'Technician',
    'Mechanic',
    'Plumber',
    'Carpenter',
  ];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(picked.map((x) => File(x.path)));
      });
    }
  }

  Future<void> _submitPost() async {
    if (_captionController.text.trim().isEmpty && _selectedImages.isEmpty) {
      return;
    }
    setState(() => _isPosting = true);
    try {
      await FeedPostService.createPost(
        caption: _captionController.text.trim(),
        imageFiles: _selectedImages,
      );
      _captionController.clear();
      setState(() => _selectedImages.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryChips(),
          Expanded(
            child: StreamBuilder<List<PostModel>>(
              stream: FeedPostService.fetchPostsStream(),
              builder: (context, snapshot) {
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildCreatePostCard()),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else if (snapshot.hasError)
                      SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'Error loading feed',
                            style: GoogleFonts.inter(color: AppColors.error),
                          ),
                        ),
                      )
                    else if ((snapshot.data ?? []).isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.dynamic_feed_outlined,
                                size: 64,
                                color: AppColors.textSecondary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No posts yet.\nBe the first to share!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final post = snapshot.data![index];
                            return _PostCard(post: post);
                          },
                          childCount: snapshot.data!.length,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final user = FeedUserResolverService.getCurrentUser();
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      title: Text(
        'Ergo Feed',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accentLight,
            backgroundImage: user?.photoURL != null && user!.photoURL!.isNotEmpty
                ? NetworkImage(user.photoURL!)
                : null,
            child: user?.photoURL == null || user!.photoURL!.isEmpty
                ? Text(
                    user?.displayName?.isNotEmpty == true
                        ? user!.displayName![0].toUpperCase()
                        : 'U',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search trades & projects',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textHint,
                ),
                prefixIcon: const Icon(Icons.search, color: AppColors.textHint, size: 20),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      color: AppColors.surface,
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cat,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreatePostCard() {
    final user = FeedUserResolverService.getCurrentUser();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.accentLight,
                backgroundImage:
                    user?.photoURL != null && user!.photoURL!.isNotEmpty
                        ? NetworkImage(user.photoURL!)
                        : null,
                child: user?.photoURL == null || user!.photoURL!.isEmpty
                    ? Text(
                        user?.displayName?.isNotEmpty == true
                            ? user!.displayName![0].toUpperCase()
                            : 'U',
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _captionController,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Share your latest work...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textHint,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImages[i],
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(color: AppColors.outline, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: _pickImages,
                child: Row(
                  children: [
                    const Icon(Icons.image_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Add Photo',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _isPosting ? null : _submitPost,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isPosting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Post',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Post Card Widget ─────────────────────────────────────────────────────────

class _PostCard extends StatefulWidget {
  final PostModel post;
  const _PostCard({required this.post});

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  late bool _isLiked;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByCurrentUser;
    _likeCount = widget.post.likeCount;
  }

  Future<void> _toggleLike() async {
    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    try {
      await FeedPostService.toggleLike(widget.post.postId);
    } catch (_) {
      // Revert on failure
      setState(() {
        _isLiked = wasLiked;
        _likeCount += wasLiked ? 1 : -1;
      });
    }
  }
  Widget _buildImage(String source, {required double width, double? height}) {
    try {
      if (source.startsWith('http')) {
        return Image.network(
          source,
          width: width,
          height: height,
          fit: height == null ? BoxFit.contain : BoxFit.cover,
          errorBuilder: (_, __, ___) => _errorContainer(height ?? 200),
        );
      } else {
        return Image.memory(
          base64Decode(source),
          width: width,
          height: height,
          fit: height == null ? BoxFit.contain : BoxFit.cover,
          errorBuilder: (_, __, ___) => _errorContainer(height ?? 200),
        );
      }
    } catch (_) {
      return _errorContainer(height ?? 200);
    }
  }

  Widget _errorContainer(double height) {
    return Container(
      height: height,
      color: AppColors.surfaceDark,
      child: const Icon(Icons.broken_image_outlined, color: AppColors.textHint, size: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(userId: post.userId),
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.accentLight,
                    backgroundImage: post.posterPhotoUrl.isNotEmpty
                        ? NetworkImage(post.posterPhotoUrl)
                        : null,
                    child: post.posterPhotoUrl.isEmpty
                        ? Text(
                            post.posterName.isNotEmpty
                                ? post.posterName[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.inter(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post.posterName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (post.posterRole.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                post.posterRole.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        timeago.format(post.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.userId == FeedUserResolverService.getCurrentUser()?.uid)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text('Delete Post', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                            content: Text('Are you sure you want to delete this post?', style: GoogleFonts.inter()),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await FeedPostService.deletePost(post.postId);
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Post', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  )
                else
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),

          // Images
          if (post.imageUrls.isNotEmpty)
            ClipRRect(
              child: post.imageUrls.length == 1
                  ? _buildImage(
                      post.imageUrls.first,
                      width: double.infinity,
                      // Omitting height allows image to display in its natural aspect ratio
                    )
                  : SizedBox(
                      height: 300, // Fixed height for carousel to avoid layout jumping
                      child: PageView.builder(
                        itemCount: post.imageUrls.length,
                        itemBuilder: (_, i) => _buildImage(
                          post.imageUrls[i],
                          width: double.infinity,
                          height: 300,
                        ),
                      ),
                    ),
            ),

          // Caption
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                post.caption,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
            child: Row(
              children: [
                // Like
                _ActionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  iconColor: _isLiked ? Colors.red : AppColors.textSecondary,
                  label: '$_likeCount',
                  onTap: _toggleLike,
                ),
                const SizedBox(width: 4),
                // Comment
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${post.commentCount}',
                  onTap: () => _openComments(context, post),
                ),
                const SizedBox(width: 4),
                // Share
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: 'Check out this post on Ergo: https://ergo.app/post/${post.postId}'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard!')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openComments(BuildContext context, PostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(post: post),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.iconColor = AppColors.textSecondary,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Comments Bottom Sheet ────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final PostModel post;
  const _CommentsSheet({required this.post});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await FeedCommentService.addComment(
        postId: widget.post.postId,
        commentText: _commentController.text.trim(),
      );
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Comments',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.post.commentCount}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.outline, height: 16),
              Expanded(
                child: StreamBuilder<List<CommentModel>>(
                  stream: FeedCommentService.listenComments(widget.post.postId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      );
                    }
                    final comments = snapshot.data ?? [];
                    if (comments.isEmpty) {
                      return Center(
                        child: Text(
                          'No comments yet. Be the first!',
                          style: GoogleFonts.inter(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _CommentTile(comment: comments[i]),
                    );
                  },
                ),
              ),
              const Divider(color: AppColors.outline, height: 1),
              // Comment input
              Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 10,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 13,
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
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isSubmitting ? null : _submitComment,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.accentLight,
          backgroundImage: comment.commenterPhotoUrl.isNotEmpty
              ? NetworkImage(comment.commenterPhotoUrl)
              : null,
          child: comment.commenterPhotoUrl.isEmpty
              ? Text(
                  comment.commenterName.isNotEmpty
                      ? comment.commenterName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
                comment.commenterName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                comment.commentText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeago.format(comment.createdAt),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
