import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import '../../models/review.dart';
import '../../theme/app_theme.dart';

/// Card displaying a single review — reviewer name, stars, comment, date.
class ReviewCard extends StatelessWidget {
  final Review review;

  const ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          // ── Reviewer row ──────────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accentLight,
                backgroundImage: review.reviewerPhotoUrl.isNotEmpty
                    ? NetworkImage(review.reviewerPhotoUrl)
                    : null,
                child: review.reviewerPhotoUrl.isEmpty
                    ? Text(
                        review.reviewerName.isNotEmpty
                            ? review.reviewerName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    RatingBarIndicator(
                      rating: review.rating,
                      itemBuilder: (context, _) => const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFBBF24),
                      ),
                      itemCount: 5,
                      itemSize: 14,
                    ),
                  ],
                ),
              ),
              // Date
              Text(
                review.createdAt != null
                    ? DateFormat('MMM d, yyyy').format(review.createdAt!)
                    : '',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
