import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/review_card.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reviews'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, provider, _) {
          final profile = provider.profile;
          final reviews = provider.reviews;
          final rating = profile?.rating ?? 0.0;
          final reviewCount = profile?.reviewCount ?? 0;

          return Column(
            children: [
              // ── Rating summary ─────────────────────────────────────────
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < rating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: const Color(0xFFFBBF24),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── Review list ───────────────────────────────────────────
              Expanded(
                child: reviews.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.rate_review_outlined,
                              size: 56,
                              color: AppColors.textHint.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No reviews yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Complete jobs to receive your first review',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textHint,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: reviews.length,
                        itemBuilder: (_, i) =>
                            ReviewCard(review: reviews[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
