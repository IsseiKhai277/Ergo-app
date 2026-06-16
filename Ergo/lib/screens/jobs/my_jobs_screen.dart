import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/job_post.dart';
import '../../services/job_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../messages/chat_screen.dart';
import '../../services/chat_service.dart';
import 'active_job_screen.dart';
import 'job_completion_screen.dart';

/// The "My Jobs" screen — ProLink style.
///
/// Workers see jobs assigned to them (workerId == uid).
/// Clients see jobs they posted (posterId == uid).
/// The top stats row, filter chips, and job cards all match the Stitch design.
class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  String _selectedFilter = 'Active';
  String _userRole = 'worker'; // fallback database role
  String _viewMode = 'worker'; // active view mode (worker or client)
  String _userName = '';
  Stream<List<JobPost>>? _jobStream;

  final _filterOptions = ['Active', 'All', 'Offered', 'Accepted', 'Completed'];

  Color get _themeColor => _viewMode == 'client' ? const Color(0xFF6B4EFF) : AppColors.primary;
  Color get _accentColor => _viewMode == 'client' ? const Color(0xFFF3E8FF) : AppColors.accentLight;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _jobStream = JobService.myWorkerJobsStream; // default fallback
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final profile = await AuthService.getUserProfile(uid);
    if (!mounted) return;
    setState(() {
      _userRole = profile?['role'] as String? ?? 'worker';
      _viewMode = _userRole; // default landing mode matching their db role
      _userName = profile?['fullName'] as String? ?? '';
      _jobStream = _viewMode == 'client'
          ? JobService.myPostedJobsStream
          : JobService.myWorkerJobsStream;
    });
  }

  List<JobPost> _applyFilter(List<JobPost> jobs) {
    if (_selectedFilter == 'All') return jobs;
    return jobs.where((j) {
      final s = j.status.toLowerCase();
      switch (_selectedFilter) {
        case 'Active':
          return s == 'active' || s == 'arrived' || s == 'active_arrived';
        case 'Offered':
          return s == 'offered';
        case 'Accepted':
          return s == 'accepted';
        case 'Completed':
          return s == 'completed';
        default:
          return true;
      }
    }).toList();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.surface,
              elevation: 0,
              scrolledUnderElevation: 1,
              shadowColor: AppColors.cardBorder,
              title: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _accentColor,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _themeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Ergo',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _themeColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {},
                  tooltip: 'Notifications',
                ),
              ],
            ),

            // ── Hero ─────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName.isNotEmpty ? _userName : 'My Jobs',
                      style: GoogleFonts.manrope(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _viewMode == 'client'
                          ? 'Jobs you have posted'
                          : "Here's your workload today",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Stats Row ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _StatsRow(
                userRole: _viewMode,
                themeColor: _themeColor,
                accentColor: _accentColor,
              ),
            ),

            // ── Filter Chips ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 0, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Switcher Toggle Button (Stitch inspired)
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _viewMode = _viewMode == 'client' ? 'worker' : 'client';
                                _jobStream = _viewMode == 'client'
                                    ? JobService.myPostedJobsStream
                                    : JobService.myWorkerJobsStream;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _themeColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _viewMode == 'client'
                                        ? 'VIEWING: CLIENT MODE'
                                        : 'VIEWING: WORKER MODE',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 20),
                        itemCount: _filterOptions.length,
                        separatorBuilder: (context2, idx) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final label = _filterOptions[index];
                          final selected = _selectedFilter == label;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedFilter = label),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _themeColor
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? _themeColor
                                      : AppColors.cardBorder,
                                ),
                              ),
                              child: Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Job List ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: StreamBuilder<List<JobPost>>(
                  stream: _jobStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return _EmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Something went wrong',
                        subtitle: snapshot.error.toString(),
                      );
                    }

                    final allJobs = snapshot.data ?? [];
                    final jobs = _applyFilter(allJobs);

                    if (jobs.isEmpty) {
                      return _EmptyState(
                        icon: Icons.work_off_outlined,
                        title: 'No ${_selectedFilter.toLowerCase()} jobs',
                        subtitle: _selectedFilter == 'All'
                            ? 'You have no jobs assigned yet.'
                            : 'Switch filters to see other jobs.',
                      );
                    }

                    return Column(
                      children: jobs
                          .map(
                            (job) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                             child: _JobCard(
                                job: job,
                                isClient: _viewMode == 'client',
                                themeColor: _themeColor,
                                accentColor: _accentColor,
                                onMessageTap: () => _openChat(context, job),
                                onMarkComplete: () =>
                                    _markComplete(context, job),
                                onStartJob: () => _startJob(context, job),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _openChat(BuildContext context, JobPost job) async {
    final otherUserId = _viewMode == 'client' ? job.workerId : job.posterId;
    final otherName = _viewMode == 'client' ? job.workerName : job.posterName;
    final otherPhoto = _viewMode == 'client'
        ? job.workerPhotoUrl
        : job.posterPhotoUrl;

    if (otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contact assigned to this job yet.')),
      );
      return;
    }

    try {
      final convId = await ChatService.getOrCreateConversation(otherUserId);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convId,
            otherUserId: otherUserId,
            otherUserName: otherName,
            otherUserPhotoUrl: otherPhoto,
            otherUserRole: '',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _startJob(BuildContext context, JobPost job) async {
    try {
      // 1. Update status to active in Firestore.
      await JobService.updateJobStatus(job.id, 'active');

      // 2. Begin 7-second location tracking.
      await LocationService.instance.startTracking(job.id);

      if (!context.mounted) return;

      // 3. Navigate to the Active Job screen.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveJobScreen(job: job),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _markComplete(BuildContext context, JobPost job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Mark as Completed?',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'This will mark "${job.title}" as completed.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Complete',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await JobService.updateJobStatus(job.id, 'completed');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${job.title} marked as completed!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Stats Row Widget
// ══════════════════════════════════════════════════════════════════════════════

class _StatsRow extends StatelessWidget {
  final String userRole;
  final Color themeColor;
  final Color accentColor;
  const _StatsRow({
    required this.userRole,
    required this.themeColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: JobService.getJobStats(userRole),
      builder: (context, snap) {
        final stats =
            snap.data ?? {'active': 0, 'completed': 0, 'totalEarnings': 0.0};
        final active = stats['active'] as int;
        final completed = stats['completed'] as int;
        final earnings = stats['totalEarnings'] as double;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  iconData: Icons.bolt_rounded,
                  iconColor: themeColor,
                  iconBg: accentColor,
                  label: 'Active Jobs',
                  value: '$active',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  iconData: Icons.check_circle_rounded,
                  iconColor: AppColors.success,
                  iconBg: const Color(0xFFDCFCE7),
                  label: 'Completed',
                  value: '$completed',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  iconData: Icons.payments_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFEF3C7),
                  label: 'Earnings',
                  value: 'RM ${earnings.toStringAsFixed(0)}',
                  smallValue: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData iconData;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final bool smallValue;

  const _StatCard({
    required this.iconData,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.smallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: smallValue ? 15 : 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Job Card Widget
// ══════════════════════════════════════════════════════════════════════════════

class _JobCard extends StatefulWidget {
  final JobPost job;
  final bool isClient;
  final Color themeColor;
  final Color accentColor;
  final VoidCallback onMessageTap;
  final VoidCallback onMarkComplete;
  final VoidCallback onStartJob;

  const _JobCard({
    required this.job,
    required this.isClient,
    required this.themeColor,
    required this.accentColor,
    required this.onMessageTap,
    required this.onMarkComplete,
    required this.onStartJob,
  });

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.015,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.985,
    ).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut));
  }

  Future<void> _handleAcceptOffer(BuildContext context) async {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);

    try {
      final job = widget.job;
      final jobOfferMap = {
        'jobId': job.id,
        'title': job.title,
        'description': job.description,
        'price': job.price,
        'location': job.location,
        'senderUid': job.posterId,
        'senderName': job.posterName,
        'senderPhoto': job.posterPhotoUrl,
        if (job.scheduledAt != null)
          'scheduledAt': Timestamp.fromDate(job.scheduledAt!),
        if (job.jobLatitude != null)
          'jobLatitude': job.jobLatitude,
        if (job.jobLongitude != null)
          'jobLongitude': job.jobLongitude,
      };

      await ChatService.acceptJobOffer(
        conversationId: job.conversationId ?? '',
        messageId: job.messageId ?? '',
        jobOffer: jobOfferMap,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer accepted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept offer: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final status = job.status.toLowerCase();
    final isCompleted = status == 'completed';
    final contactName = widget.isClient ? job.workerName : job.posterName;
    final contactPhoto = widget.isClient
        ? job.workerPhotoUrl
        : job.posterPhotoUrl;
    final contactLabel = widget.isClient ? 'Worker' : 'Client';

    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) => _scaleCtrl.reverse(),
      onTapCancel: () => _scaleCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Opacity(
          opacity: isCompleted ? 0.75 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFFF8FAFC) : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCompleted
                    ? AppColors.cardBorder
                    : AppColors.cardBorder,
                style: isCompleted ? BorderStyle.solid : BorderStyle.solid,
              ),
              boxShadow: isCompleted
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Avatar ──────────────────────────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: contactPhoto.isNotEmpty
                          ? Image.network(
                              contactPhoto,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx2, err, stack) =>
                                  _avatarPlaceholder(contactName),
                            )
                          : _avatarPlaceholder(contactName),
                    ),
                    const SizedBox(width: 14),

                    // ── Job Info ─────────────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title + Badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  job.title,
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusBadge(
                                status: job.status,
                                isClientMode: widget.isClient,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Client / Worker name
                          if (contactName.isNotEmpty)
                            Text(
                              '$contactLabel: $contactName',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          const SizedBox(height: 8),

                          // Location & Schedule chips
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if (job.location.isNotEmpty)
                                _MetaChip(
                                  icon: Icons.location_on_outlined,
                                  text: job.location,
                                  iconColor: widget.themeColor,
                                ),
                              if (job.scheduledAt != null)
                                _MetaChip(
                                  icon: Icons.schedule_rounded,
                                  text: _formatScheduled(job.scheduledAt!),
                                  iconColor: widget.themeColor,
                                )
                              else
                                _MetaChip(
                                  icon: Icons.access_time_rounded,
                                  text: timeago.format(job.createdAt),
                                  iconColor: widget.themeColor,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Price ────────────────────────────────────────────────
                    const SizedBox(width: 10),
                    Text(
                      'RM ${job.price.toStringAsFixed(0)}',
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isCompleted
                            ? AppColors.textSecondary
                            : widget.themeColor,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),

                // ── Action Buttons (Active / Arrived only) ───────────────────
                if (!isCompleted &&
                    (status == 'active' ||
                        status == 'arrived' ||
                        status == 'active_arrived')) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onMessageTap,
                          icon: const Icon(Icons.message_outlined, size: 15),
                          label: Text(
                            widget.isClient
                                ? 'Message Worker'
                                : 'Message Client',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ),
                      if (widget.isClient) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobCompletionScreen(job: job),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 15,
                            ),
                            label: Text(
                              'Job Complete',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: Size.zero,
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // ── Buttons for Accepted jobs ────────────────────────────────
                if (!isCompleted && status == 'accepted') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Message button (both sides)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onMessageTap,
                          icon: const Icon(Icons.message_outlined, size: 15),
                          label: Text(
                            widget.isClient
                                ? 'Message Worker'
                                : 'Message Client',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ),
                      // Start Job button — worker only
                      if (!widget.isClient) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onStartJob,
                            icon: const Icon(
                              Icons.directions_run_rounded,
                              size: 15,
                            ),
                            label: Text(
                              'Start Job',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.themeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: Size.zero,
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // ── Buttons for Offered jobs ─────────────────────────────────
                if (!isCompleted && status == 'offered') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Message button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onMessageTap,
                          icon: const Icon(Icons.message_outlined, size: 15),
                          label: Text(
                            widget.isClient
                                ? 'Message Worker'
                                : 'Message Client',
                            style: GoogleFonts.inter(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ),
                      // Accept button (worker only)
                      if (!widget.isClient) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAccepting ? null : () => _handleAcceptOffer(context),
                            icon: _isAccepting
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 15,
                                  ),
                            label: Text(
                              _isAccepting ? 'Accepting...' : 'Accept Offer',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.themeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: Size.zero,
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(String name) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: widget.accentColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: widget.themeColor,
          ),
        ),
      ),
    );
  }

  String _formatScheduled(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final day = DateTime(dt.year, dt.month, dt.day);

    final timeStr =
        '${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour < 12 ? 'AM' : 'PM'}';

    if (day == today) return 'Today, $timeStr';
    if (day == tomorrow) return 'Tomorrow, $timeStr';
    return '${dt.day}/${dt.month}/${dt.year}, $timeStr';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Helper Widgets
// ══════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isClientMode;
  const _StatusBadge({
    required this.status,
    this.isClientMode = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status.toLowerCase()) {
      case 'active':
        if (isClientMode) {
          bg = const Color(0xFFF3E8FF);
          fg = const Color(0xFF6B4EFF);
        } else {
          bg = const Color(0xFFD1FAE5);
          fg = const Color(0xFF065F46);
        }
        break;
      case 'accepted':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1E40AF);
        break;
      case 'completed':
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
        break;
      case 'offered':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF6B21A8);
        break;
      case 'open':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
      default:
        bg = AppColors.accentLight;
        fg = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? iconColor;
  const _MetaChip({
    required this.icon,
    required this.text,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: iconColor ?? AppColors.primary),
        const SizedBox(width: 3),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.cardBorder),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
