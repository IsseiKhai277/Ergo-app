import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../theme/app_theme.dart';
import '../../models/job_post.dart';
import '../../services/job_service.dart';
import '../../services/auth_service.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isLoading = false;
  bool _isLocating = false;

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = "";
        if (place.street != null && place.street!.isNotEmpty) {
          address += "${place.street}, ";
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          address += "${place.locality}, ";
        }
        address += "${place.country}";
        _locationController.text = address.replaceAll(RegExp(r',\s*$'), '');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      // Fetch user profile to get the full name and photo
      final profile = await AuthService.getUserProfile(currentUser.uid);
      final posterName = profile?['fullName'] ?? currentUser.displayName ?? 'Unknown User';
      final posterPhotoUrl = profile?['photoUrl'] ?? currentUser.photoURL ?? '';

      final newJob = JobPost(
        id: '', // Will be assigned by Firestore
        posterId: currentUser.uid,
        posterName: posterName,
        posterPhotoUrl: posterPhotoUrl,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        location: _locationController.text.trim(),
        createdAt: DateTime.now(),
      );

      await JobService.createJobPost(newJob);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Job posted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post job: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(
          'Post a Job',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Job Details',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _titleController,
                label: 'Job Title',
                hint: 'e.g. Fix leaking pipe',
                validator: (v) => v!.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descController,
                label: 'Description',
                hint: 'Describe what needs to be done...',
                maxLines: 4,
                validator: (v) => v!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _priceController,
                label: 'Price / Hourly Rate (\$)',
                hint: 'e.g. 65',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v!.isEmpty) return 'Please enter a price';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              Text(
                'Location',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _locationController,
                      label: '', // Label handled above
                      hint: 'Enter address or use GPS',
                      validator: (v) => v!.isEmpty ? 'Please enter a location' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _isLocating ? null : _getCurrentLocation,
                      icon: _isLocating 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location, color: AppColors.primary),
                      tooltip: 'Get Current Location',
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Post Job',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.inter(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
