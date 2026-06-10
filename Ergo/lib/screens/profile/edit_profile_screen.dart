import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final profile = context.read<ProfileProvider>().profile;
      if (profile != null) {
        _nameController.text = profile.fullName;
        _phoneController.text = profile.phoneNumber;
        _bioController.text = profile.bio;
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProfileProvider>();
    final success = await provider.updateProfile(
      fullName: _nameController.text,
      phoneNumber: _phoneController.text,
      bio: _bioController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Profile updated successfully!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to update profile'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUpdating =
        context.select<ProfileProvider, bool>((p) => p.isUpdating);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: isUpdating ? null : _save,
              child: isUpdating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar section ──────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Consumer<ProfileProvider>(
                      builder: (_, provider, __) {
                        return Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accentLight,
                            border:
                                Border.all(color: AppColors.primary, width: 2),
                            image: (provider.profile?.photoUrl.isNotEmpty == true)
                                ? DecorationImage(
                                    image: NetworkImage(
                                        provider.profile!.photoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child:
                              (provider.profile?.photoUrl.isNotEmpty != true)
                                  ? const Icon(Icons.person_rounded,
                                      size: 44, color: AppColors.primary)
                                  : null,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Change photo on Profile screen',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Full Name ───────────────────────────────────────────────
              _buildLabel('Full Name *'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: AppColors.textHint, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Full name is required';
                  }
                  if (v.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // ── Phone Number ────────────────────────────────────────────
              _buildLabel('Phone Number'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '+60 12-345 6789',
                  prefixIcon: Icon(Icons.phone_outlined,
                      color: AppColors.textHint, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // Optional
                  // Basic international phone format check
                  final regex = RegExp(r'^\+?[0-9\s\-().]{7,20}$');
                  if (!regex.hasMatch(v.trim())) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // ── Bio ─────────────────────────────────────────────────────
              _buildLabel('Bio'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Tell clients about yourself, your experience, and what you offer...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),

              // ── Save Button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isUpdating ? null : _save,
                  child: isUpdating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
