import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../models/job_post.dart';

class JobDetailsScreen extends StatelessWidget {
  final JobPost job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Cover Area
                Container(
                  height: 200,
                  width: double.infinity,
                  color: AppColors.primaryLight,
                  child: Center(
                    child: Icon(
                      Icons.work_outline,
                      size: 80,
                      color: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row (Price and Title)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              job.title,
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '\$${job.price.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Meta Info (Location & Time)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              job.location,
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Posted ${timeago.format(job.createdAt)}',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Poster Info
                      Text(
                        'Posted by',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.accentLight,
                            backgroundImage: job.posterPhotoUrl.isNotEmpty
                                ? NetworkImage(job.posterPhotoUrl)
                                : null,
                            child: job.posterPhotoUrl.isEmpty
                                ? Text(
                                    job.posterName.isNotEmpty ? job.posterName[0].toUpperCase() : '?',
                                    style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            job.posterName,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Description
                      Text(
                        'Job Description',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        job.description,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          height: 1.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      
                      // Extra padding for bottom button
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Apply Button (Bottom fixed)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement Apply logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Application sent!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Apply for Job',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
