import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/job_post.dart';
import '../../services/location_service.dart';
import '../../services/job_service.dart';
import '../../theme/app_theme.dart';

/// Screen shown when a worker is active on a job.
class ActiveJobScreen extends StatelessWidget {
  final JobPost job;

  const ActiveJobScreen({super.key, required this.job});

  Future<void> _onArrived(BuildContext context) async {
    // Stop the 7-second tracking timer.
    LocationService.instance.stopTracking();

    // Delete worker location fields from Firestore.
    await JobService.clearWorkerLocation(job.id);

    // Update job status to 'arrived' (ongoing but worker arrived).
    await JobService.updateJobStatus(job.id, 'arrived');

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'You have arrived at "${job.title}"!',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // ── App Bar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          'On Job',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      // ── Body ─────────────────────────────────────────────────────────────────
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('jobs').doc(job.id).snapshots(),
        builder: (context, snapshot) {
          JobPost currentJob = job;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data();
            if (data != null) {
              currentJob = JobPost.fromMap(data, snapshot.data!.id);
            }
          }

          // If the job has been completed by the client, automatically pop!
          if (currentJob.status == 'completed') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Job has been marked completed by the client!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            });
          }

          final status = currentJob.status.toLowerCase();
          final hasArrived = status == 'arrived' || status == 'active_arrived';

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),

                // Status indicator
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_run_rounded,
                    size: 52,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  hasArrived ? 'You have arrived' : 'You are currently on a job',
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Text(
                  currentJob.title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                if (currentJob.location.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          currentJob.location,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // Live tracking badge or Arrived badge
                if (!hasArrived)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gps_fixed, size: 14, color: Color(0xFF16A34A)),
                        const SizedBox(width: 6),
                        Text(
                          'Live tracking active',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: Color(0xFF6B21A8)),
                        const SizedBox(width: 6),
                        Text(
                          'Arrived at destination',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B21A8),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                Text(
                  hasArrived
                      ? 'Waiting for the client to review and complete the job.'
                      : 'Your client can see your location.\nThis screen will be expanded with a live map.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(),

                // ── Arrived Button ──────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: hasArrived ? null : () => _onArrived(context),
                    icon: Icon(hasArrived ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded),
                    label: Text(
                      hasArrived ? 'Arrived' : 'I Have Arrived',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasArrived ? Colors.grey[400] : AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
