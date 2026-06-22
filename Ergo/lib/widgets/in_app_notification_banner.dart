import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class InAppNotificationBanner {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    required String? photoUrl,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Dismiss any active banner first
    dismiss();

    final overlayState = Overlay.of(context);
    
    _currentEntry = OverlayEntry(
      builder: (context) {
        return _BannerWidget(
          title: title,
          message: message,
          photoUrl: photoUrl,
          icon: icon,
          color: color,
          onTap: () {
            dismiss();
            onTap();
          },
          onDismiss: dismiss,
        );
      },
    );

    overlayState.insert(_currentEntry!);
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      dismiss();
    });
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _BannerWidget extends StatelessWidget {
  final String title;
  final String message;
  final String? photoUrl;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _BannerWidget({
    required this.title,
    required this.message,
    this.photoUrl,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          tween: Tween(begin: -100.0, end: 12.0),
          builder: (context, topPadding, child) {
            return Padding(
              padding: EdgeInsets.only(top: topPadding, left: 16, right: 16),
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: color.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Icon / Avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: photoUrl != null && photoUrl!.isNotEmpty
                            ? Image.network(
                                photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  icon,
                                  color: color,
                                  size: 22,
                                ),
                              )
                            : Icon(
                                icon,
                                color: color,
                                size: 22,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            message,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close button
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textHint,
                      ),
                      onPressed: onDismiss,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
