import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skill_chip.dart';
import 'edit_profile_screen.dart';
import 'reviews_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize profile stream after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().init();
    });
  }

  // ─── Add Skill Dialog ──────────────────────────────────────────────────────
  void _showAddSkillDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Skill',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Flutter, Python, Design',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((skill) async {
      if (skill != null && skill.toString().trim().isNotEmpty && mounted) {
        await context.read<ProfileProvider>().addSkill(skill.toString());
      }
    });
  }

  // ─── AI Resume Upload ──────────────────────────────────────────────────────
  Future<void> _handleResumeUpload() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
        allowMultiple: false,
      );
    } catch (_) {
      // File picker cancelled or unavailable
      return;
    }

    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    if (file.path == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LoadingDialog(
        message: 'Uploading resume & extracting skills...',
      ),
    );

    final provider = context.read<ProfileProvider>();
    final suggestedSkills = await provider.uploadResumeAndExtractSkills(
      resumeFile: File(file.path!),
      fileName: file.name,
    );

    if (!mounted) return;
    Navigator.pop(context); // close loading dialog

    if (suggestedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(provider.errorMessage ?? 'No skills found in resume.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // Show skill confirmation modal
    _showSkillConfirmationModal(suggestedSkills);
  }

  // ─── Skill Confirmation Modal ──────────────────────────────────────────────
  void _showSkillConfirmationModal(List<String> suggestedSkills) {
    final selectedSkills = List<String>.from(suggestedSkills);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Detected Skills',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Select skills to add to your profile',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestedSkills.map((skill) {
                      final selected = selectedSkills.contains(skill);
                      return FilterChip(
                        label: Text(skill),
                        selected: selected,
                        onSelected: (val) {
                          setModalState(() {
                            if (val) {
                              selectedSkills.add(skill);
                            } else {
                              selectedSkills.remove(skill);
                            }
                          });
                        },
                        selectedColor: AppColors.accentLight,
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            if (selectedSkills.isNotEmpty && mounted) {
                              // Merge with existing skills (deduplicate)
                              final existing =
                                  context.read<ProfileProvider>().profile?.skills ?? [];
                              final merged = {
                                ...existing,
                                ...selectedSkills,
                              }.toList();
                              await context
                                  .read<ProfileProvider>()
                                  .saveSkills(merged);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${selectedSkills.length} skills added!'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Save Skills'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final profile = provider.profile;
        final user = FirebaseAuth.instance.currentUser;

        final completion = profile?.completionPercentage ?? 0;
        final isVerified = profile?.isVerified ?? false;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              // ── App Bar with gradient header ─────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.primary,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_rounded, color: Colors.white),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildProfileHeader(
                    context,
                    provider,
                    profile,
                    user,
                    isVerified,
                    completion,
                  ),
                ),
              ),

              // ── Body content ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Edit Profile Button
                      _buildEditProfileButton(context, profile),
                      const SizedBox(height: 20),

                      // Rating Section
                      _buildRatingSection(context, provider),
                      const SizedBox(height: 20),

                      // Skills Section
                      _buildSkillsSection(context, provider, profile),
                      const SizedBox(height: 20),

                      // Contact Information
                      _buildContactSection(context, profile),
                      const SizedBox(height: 20),

                      // Resume Section
                      _buildResumeSection(context, provider, profile),
                      const SizedBox(height: 20),

                      // My Posts Section
                      _buildMyPostsSection(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Profile Header ────────────────────────────────────────────────────────
  Widget _buildProfileHeader(
    BuildContext context,
    ProfileProvider provider,
    dynamic profile,
    User? user,
    bool isVerified,
    int completion,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              ProfileAvatar(
                photoUrl: profile?.photoUrl ?? user?.photoURL,
                radius: 46,
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      profile?.fullName ?? user?.displayName ?? 'Your Name',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // Email
                    Text(
                      profile?.email ?? user?.email ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // UID
                    Text(
                      'ID: ${(user?.uid ?? '').substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.6),
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Status badge
                    _buildStatusBadge(isVerified, completion),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Completion ring
              CircularPercentIndicator(
                radius: 36,
                lineWidth: 5,
                percent: completion / 100,
                center: Text(
                  '$completion%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                progressColor: const Color(0xFF4ADE80),
                backgroundColor: Colors.white.withOpacity(0.25),
                circularStrokeCap: CircularStrokeCap.round,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isVerified, int completion) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified
            ? const Color(0xFF16A34A).withOpacity(0.2)
            : const Color(0xFFDC2626).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVerified
              ? const Color(0xFF4ADE80).withOpacity(0.5)
              : const Color(0xFFFCA5A5).withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified
                ? Icons.verified_rounded
                : Icons.warning_amber_rounded,
            size: 13,
            color: isVerified
                ? const Color(0xFF4ADE80)
                : const Color(0xFFFCA5A5),
          ),
          const SizedBox(width: 5),
          Text(
            isVerified ? 'Verified' : 'Incomplete Profile',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isVerified
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFFFCA5A5),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Edit Profile Button ───────────────────────────────────────────────────
  Widget _buildEditProfileButton(BuildContext context, dynamic profile) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text('Edit Profile'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: context.read<ProfileProvider>(),
              child: const EditProfileScreen(),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Rating Section ────────────────────────────────────────────────────────
  Widget _buildRatingSection(BuildContext context, ProfileProvider provider) {
    final reviews = provider.reviews;
    final int reviewCount = reviews.length;
    double rating = 0.0;
    if (reviewCount > 0) {
      double total = reviews.fold<double>(0.0, (acc, r) => acc + r.rating);
      rating = total / reviewCount;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const ReviewsScreen(),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.star_rounded,
                  color: Color(0xFFFBBF24), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rating == 0.0
                        ? 'No ratings yet'
                        : rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (rating > 0)
                    RatingBarIndicator(
                      rating: rating,
                      itemBuilder: (context, _) => const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFBBF24),
                      ),
                      itemCount: 5,
                      itemSize: 16,
                    ),
                  Text(
                    '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  // ─── Skills Section ────────────────────────────────────────────────────────
  Widget _buildSkillsSection(
    BuildContext context,
    ProfileProvider provider,
    dynamic profile,
  ) {
    final skills = profile?.skills as List<String>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Skills',
            action: TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Skill'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                minimumSize: Size.zero,
              ),
              onPressed: _showAddSkillDialog,
            ),
          ),
          if (skills.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No skills added yet. Add skills to improve your profile.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills
                  .map((skill) => SkillChip(
                        label: skill,
                        onRemove: () =>
                            provider.removeSkill(skill),
                      ))
                  .toList(),
            ),

          const SizedBox(height: 12),

          // AI Detect button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: provider.isUploadingResume
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(provider.isUploadingResume
                  ? 'Processing...'
                  : 'AI Detect from Resume'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed:
                  provider.isUploadingResume ? null : _handleResumeUpload,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Contact Section ───────────────────────────────────────────────────────
  Widget _buildContactSection(BuildContext context, dynamic profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Contact Information',
            action: IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: AppColors.primary),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: context.read<ProfileProvider>(),
                    child: const EditProfileScreen(),
                  ),
                ),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          _buildContactRow(
            icon: Icons.phone_rounded,
            label: 'Phone',
            value: profile?.phoneNumber?.isNotEmpty == true
                ? profile!.phoneNumber
                : 'Not provided',
          ),
          const SizedBox(height: 10),
          _buildContactRow(
            icon: Icons.email_rounded,
            label: 'Email',
            value: profile?.email ?? FirebaseAuth.instance.currentUser?.email ?? '',
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Resume Section ────────────────────────────────────────────────────────
  Widget _buildResumeSection(
    BuildContext context,
    ProfileProvider provider,
    dynamic profile,
  ) {
    final hasResume =
        profile?.resumeUrl != null && (profile!.resumeUrl as String).isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Resume'),
          if (hasResume)
            Row(
              children: [
                const Icon(Icons.description_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Resume uploaded',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _handleResumeUpload,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    'Replace',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            )
          else
            const Text(
              'No resume uploaded yet.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  // ─── My Posts Section ─────────────────────────────────────────────────────
  Widget _buildMyPostsSection(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'My Posts'),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('userId', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Error loading posts: ${snapshot.error}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.error),
                  ),
                );
              }
              final docs = snapshot.data?.docs ?? [];
              // Sort by createdAt descending in Dart to avoid needing a composite index
              docs.sort((a, b) {
                final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime);
              });
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No posts yet. Share something on Ergo Feed!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }
              return ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(color: AppColors.outline, height: 1),
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final imageUrls = List<String>.from(data['imageUrls'] ?? []);
                  final caption = (data['caption'] ?? '') as String;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final likeCount = data['likeCount'] ?? 0;
                  final commentCount = data['commentCount'] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrls.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _decodeImage(imageUrls.first),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (caption.isNotEmpty)
                          Text(
                            caption,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.favorite_border, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text('$likeCount', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 12),
                            const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text('$commentCount', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                            const Spacer(),
                            Text(
                              timeago.format(createdAt),
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _decodeImage(String source) {
    try {
      if (source.startsWith('http')) {
        return Image.network(
          source,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } else {
        return Image.memory(
          base64Decode(source),
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      }
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

// ─── Loading Dialog ──────────────────────────────────────────────────────────
class _LoadingDialog extends StatelessWidget {
  final String message;
  const _LoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
