import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../providers/active_job_provider.dart';
import '../search/search_screen.dart';
import '../feed/ergo_feed_screen.dart';
import '../messages/messages_screen.dart';
import '../profile/profile_screen.dart';
import '../jobs/my_jobs_screen.dart';
import '../../services/job_service.dart';
import '../../models/job_post.dart';
import '../jobs/active_job_screen.dart';
import '../jobs/worker_tracking_screen.dart';
import '../../services/chat_service.dart';
import '../../services/auth_service.dart';
import '../../models/conversation_model.dart';
import '../../widgets/in_app_notification_banner.dart';
import '../messages/chat_screen.dart';
import '../../services/sound_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // The pages for each bottom navigation tab.
  final List<Widget> _pages = [
    const MyJobsScreen(),       // 0: My Jobs (ProLink style)
    const SearchScreen(),        // 1: Search Users
    const ErgoFeedScreen(),     // 2: What's Up / Ergo Feed
    const MessagesScreen(),     // 3: Messages
    const ProfileScreen(),      // 4: Profile
  ];

  StreamSubscription<List<ConversationModel>>? _convoSub;
  StreamSubscription<List<JobPost>>? _clientJobsSub;
  StreamSubscription<List<JobPost>>? _workerJobsSub;

  bool _isFirstConvoEmit = true;
  bool _isFirstClientJobsEmit = true;
  bool _isFirstWorkerJobsEmit = true;

  final Map<String, int> _lastUnreadCounts = {};
  final Map<String, String> _lastClientJobStatuses = {};
  final Map<String, String> _lastWorkerJobStatuses = {};

  @override
  void initState() {
    super.initState();
    _startListeningNotifications();
  }

  @override
  void dispose() {
    _convoSub?.cancel();
    _clientJobsSub?.cancel();
    _workerJobsSub?.cancel();
    InAppNotificationBanner.dismiss();
    super.dispose();
  }

  void _startListeningNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    // 1. Listen to new messages/conversations
    _convoSub = ChatService.streamConversations().listen((convos) {
      if (_isFirstConvoEmit) {
        for (final c in convos) {
          _lastUnreadCounts[c.id] = c.unreadCount[uid] ?? 0;
        }
        _isFirstConvoEmit = false;
        return;
      }

      for (final c in convos) {
        final prevUnread = _lastUnreadCounts[c.id] ?? 0;
        final currentUnread = c.unreadCount[uid] ?? 0;

        if (currentUnread > prevUnread && c.lastSenderId != uid) {
          SoundService.playNotificationSound();
          final isJobOffer = c.lastMessage.startsWith('Job Offer:');
          final otherUserId = ChatService.getOtherUserId(c);

          _showInAppNotification(
            title: isJobOffer ? 'New Job Offer!' : 'New Message',
            message: c.lastMessage,
            senderId: otherUserId,
            onTap: () => _openConversationChat(c),
          );
        }
        _lastUnreadCounts[c.id] = currentUnread;
      }
    });

    // 2. Listen to Client status updates (Worker accepts client's job offer)
    _clientJobsSub = JobService.myPostedJobsStream.listen((jobs) {
      if (_isFirstClientJobsEmit) {
        for (final j in jobs) {
          _lastClientJobStatuses[j.id] = j.status;
        }
        _isFirstClientJobsEmit = false;
        return;
      }

      for (final j in jobs) {
        final prevStatus = _lastClientJobStatuses[j.id];
        final currentStatus = j.status;

        if (prevStatus == 'offered' && currentStatus == 'accepted') {
          SoundService.playNotificationSound();
          final workerName = j.workerName.isNotEmpty ? j.workerName : 'A worker';

          if (!mounted) return;
          InAppNotificationBanner.show(
            context,
            title: 'Job Offer Accepted! 🎉',
            message: '$workerName accepted your offer for "${j.title}"',
            photoUrl: j.workerPhotoUrl,
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF16A34A),
            onTap: () => _openConversationWithUser(j.workerId),
          );
        }
        _lastClientJobStatuses[j.id] = currentStatus;
      }
    });

    // 3. Listen to Worker status updates (Client completes worker's job)
    _workerJobsSub = JobService.myWorkerJobsStream.listen((jobs) {
      if (_isFirstWorkerJobsEmit) {
        for (final j in jobs) {
          _lastWorkerJobStatuses[j.id] = j.status;
        }
        _isFirstWorkerJobsEmit = false;
        return;
      }

      for (final j in jobs) {
        final prevStatus = _lastWorkerJobStatuses[j.id];
        final currentStatus = j.status;

        if (prevStatus != 'completed' && currentStatus == 'completed') {
          SoundService.playNotificationSound();
          final clientName = j.posterName.isNotEmpty ? j.posterName : 'The client';

          if (!mounted) return;
          InAppNotificationBanner.show(
            context,
            title: 'Job Completed! 🏆',
            message: '$clientName completed & rated your job: "${j.title}"',
            photoUrl: j.posterPhotoUrl,
            icon: Icons.emoji_events_rounded,
            color: const Color(0xFFD97706),
            onTap: () {
              setState(() {
                _currentIndex = 0; // Go to "My Jobs" screen
              });
            },
          );
        }
        _lastWorkerJobStatuses[j.id] = currentStatus;
      }
    });

  }

  Future<void> _showInAppNotification({
    required String title,
    required String message,
    required String senderId,
    required VoidCallback onTap,
  }) async {
    String? name;
    String? photoUrl;
    IconData icon = Icons.message_rounded;
    Color color = AppColors.primary;

    if (title.contains('Job')) {
      icon = Icons.work_rounded;
      color = const Color(0xFF6B4EFF);
    }

    if (senderId.isNotEmpty) {
      final profile = await AuthService.getUserProfile(senderId);
      if (profile != null) {
        name = profile['fullName'] as String? ?? profile['name'] as String?;
        photoUrl = profile['photoUrl'] as String? ?? profile['photoURL'] as String?;
      }
    }

    if (!mounted) return;

    InAppNotificationBanner.show(
      context,
      title: name != null ? '$title from $name' : title,
      message: message,
      photoUrl: photoUrl,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }

  void _openConversationChat(ConversationModel convo) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final otherUserId = convo.participantIds.firstWhere((id) => id != uid, orElse: () => '');
    
    AuthService.getUserProfile(otherUserId).then((profile) {
      if (!mounted) return;
      final otherName = profile?['fullName'] as String? ?? 'User';
      final otherPhoto = profile?['photoUrl'] as String? ?? '';
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: convo.id,
            otherUserId: otherUserId,
            otherUserName: otherName,
            otherUserPhotoUrl: otherPhoto,
            otherUserRole: '',
          ),
        ),
      );
    });
  }

  void _openConversationWithUser(String otherUserId) {
    if (otherUserId.isEmpty) return;
    ChatService.getOrCreateConversation(otherUserId).then((convId) {
      AuthService.getUserProfile(otherUserId).then((profile) {
        if (!mounted) return;
        final otherName = profile?['fullName'] as String? ?? 'User';
        final otherPhoto = profile?['photoUrl'] as String? ?? '';
        
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
      });
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeJob = context.watch<ActiveJobProvider>().activeJob;
    final activeClientJob = context.watch<ActiveJobProvider>().activeClientJob;

    // Check if the client needs to see the "Worker has arrived" popup
    if (activeClientJob != null && activeClientJob.status == 'arrived') {
      // Show popup in a post-frame callback so it doesn't interrupt build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showArrivedPopup(context, activeClientJob);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Main page content ───────────────────────────────────────────────
          _pages[_currentIndex],

          // ── Global "Back to Job" floating green button (for worker) ─────────
          // Visible on all tabs whenever the worker has a job with status='active'.
          if (activeJob != null)
            Positioned(
              bottom: 90, // Sits above the bottom navigation bar
              right: 20,
              child: _ActiveJobFab(
                jobTitle: activeJob.title,
                color: const Color(0xFF16A34A),
                icon: Icons.directions_run_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActiveJobScreen(job: activeJob),
                    ),
                  );
                },
              ),
            ),

          // ── Global "Worker On Way" floating blue button (for client) ──────────
          // Visible on all tabs whenever the client has a job with status='active'.
          if (activeClientJob != null && activeClientJob.status == 'active')
            Positioned(
              bottom: 90,
              right: 20,
              child: _ActiveJobFab(
                jobTitle: activeClientJob.title,
                color: const Color(0xFF2563EB), // Rich blue
                icon: Icons.work_rounded,
                label: 'On Their Way',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkerTrackingScreen(job: activeClientJob),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.work_outline_rounded),
              label: 'My Jobs',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.whatshot_rounded),
              label: "What's Up",
            ),
            BottomNavigationBarItem(
              icon: StreamBuilder<int>(
                stream: ChatService.streamUnreadConversationsCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count > 0) {
                    return Badge(
                      label: Text(
                        count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.message_rounded),
                    );
                  }
                  return const Icon(Icons.message_rounded);
                },
              ),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // ─── Modal Popup for "Worker Has Arrived" ───────────────────────────
  bool _isPopupShowing = false;
  void _showArrivedPopup(BuildContext context, JobPost job) {
    if (_isPopupShowing) return;
    _isPopupShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppColors.background,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDBEAFE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF2563EB),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  'THE WORKER HAS ARRIVED',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Subtitle
                Text(
                  '${job.workerName.isNotEmpty ? job.workerName : "The worker"} has arrived at the location for job:\n"${job.title}"',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      // Update job status to 'active_arrived', so it doesn't popup again and remains active
                      await JobService.updateJobStatus(job.id, 'active_arrived');
                      _isPopupShowing = false;
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(
                      'Yes, the worker has arrived',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _isPopupShowing = false;
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Global Active Job Floating Button
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveJobFab extends StatefulWidget {
  final String jobTitle;
  final VoidCallback onTap;
  final Color color;
  final IconData icon;
  final String label;

  const _ActiveJobFab({
    required this.jobTitle,
    required this.onTap,
    required this.color,
    required this.icon,
    this.label = 'On Job',
  });

  @override
  State<_ActiveJobFab> createState() => _ActiveJobFabState();
}

class _ActiveJobFabState extends State<_ActiveJobFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
