import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';

/// Tappable circular avatar with camera overlay.
/// Handles: pick → crop → upload flow.
class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    this.radius = 50,
  });

  Future<void> _pickAndUpload(BuildContext context) async {
    final provider = context.read<ProfileProvider>();

    // ── Step 1: Show source picker dialog ──────────────────────────────────
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Change Profile Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.accentLight,
                child: Icon(Icons.photo_library_rounded, color: AppColors.primary),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.accentLight,
                child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              ),
              title: const Text('Take a Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !context.mounted) return;

    // ── Step 2: Pick image ─────────────────────────────────────────────────
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1080,
    );
    if (picked == null || !context.mounted) return;

    // ── Step 3: Crop image ─────────────────────────────────────────────────
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (cropped == null || !context.mounted) return;

    // ── Step 4: Upload to Firebase Storage ─────────────────────────────────
    final success = await provider.uploadProfileImage(File(cropped.path));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Profile photo updated!'
                : (provider.errorMessage ?? 'Upload failed'),
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUploading = context.select<ProfileProvider, bool>(
      (p) => p.isUploadingImage,
    );

    return GestureDetector(
      onTap: isUploading ? null : () => _pickAndUpload(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Avatar ────────────────────────────────────────────────────────
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentLight,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              image: (photoUrl != null && photoUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (photoUrl == null || photoUrl!.isEmpty)
                ? Icon(
                    Icons.person_rounded,
                    size: radius,
                    color: AppColors.primary,
                  )
                : null,
          ),

          // ── Loading overlay ───────────────────────────────────────────────
          if (isUploading)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black26,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),

          // ── Camera badge ──────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
