import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animations/animations.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../theme/app_theme.dart';
import '../../models/job_post.dart';
import '../../services/job_service.dart';
import '../../services/auth_service.dart';
import '../jobs/post_job_screen.dart';
import '../jobs/job_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.hub_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Bulletin Board',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService.signOut();
            },
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: 'Log out',
          ),
        ],
      ),
      body: StreamBuilder<List<JobPost>>(
        stream: JobService.jobsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading jobs',
                style: GoogleFonts.inter(color: AppColors.error),
              ),
            );
          }

          final jobs = snapshot.data ?? [];

          if (jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.work_off_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No jobs posted yet.',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final job = jobs[index];
              return _buildJobCard(context, job);
            },
          );
        },
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, JobPost job) {
    void openDetails() {
      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              JobDetailsScreen(job: job),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: openDetails,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title and Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '\$${job.price.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description Summary
              Text(
                job.description,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 16),
              const Divider(color: AppColors.outline),
              const SizedBox(height: 12),

              // Footer: Profile and Apply Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Poster Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accentLight,
                        backgroundImage: job.posterPhotoUrl.isNotEmpty
                            ? NetworkImage(job.posterPhotoUrl)
                            : null,
                        child: job.posterPhotoUrl.isEmpty
                            ? Text(
                                job.posterName.isNotEmpty
                                    ? job.posterName[0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.posterName,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            timeago.format(job.createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Apply Button
                  FilledButton(
                    onPressed: openDetails, // Opens the details screen
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Apply',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
