import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../models/job_post.dart';
import '../../services/job_service.dart';
import '../../services/auth_service.dart';
import 'location_picker_screen.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();

  bool _isLoading = false;
  bool _isLocating = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Map-picked coordinates (nullable — user may skip pinning)
  LatLng? _pickedLocation;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ─── GPS Location ──────────────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

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

      final position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        String address = '';
        if (place.street != null && place.street!.isNotEmpty) {
          address += '${place.street}, ';
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          address += '${place.locality}, ';
        }
        address += '${place.country}';
        _locationController.text =
            address.replaceAll(RegExp(r',\s*$'), '');
        _pickedLocation = LatLng(position.latitude, position.longitude);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _pinOnMap() async {
    final result = await Navigator.push<LatLng?>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: _pickedLocation,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _pickedLocation = result;
        _isLocating = true;
      });
      try {
        final placemarks =
            await placemarkFromCoordinates(result.latitude, result.longitude);
        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          String address = '';
          if (place.street != null && place.street!.isNotEmpty) {
            address += '${place.street}, ';
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            address += '${place.locality}, ';
          }
          address += '${place.country}';
          setState(() {
            _locationController.text =
                address.replaceAll(RegExp(r',\s*$'), '');
          });
        } else {
          setState(() {
            _locationController.text =
                '${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}';
          });
        }
      } catch (_) {
        setState(() {
          _locationController.text =
              '${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}';
        });
      } finally {
        setState(() => _isLocating = false);
      }
    }
  }

  // ─── Date / Time Pickers ───────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
          dialogBackgroundColor: AppColors.background,
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
          dialogBackgroundColor: AppColors.background,
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ─── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitJob() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a job title')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = AuthService.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final profile = await AuthService.getUserProfile(currentUser.uid);
      final posterName =
          profile?['fullName'] ?? currentUser.displayName ?? 'Unknown User';
      final posterPhotoUrl =
          profile?['photoUrl'] ?? currentUser.photoURL ?? '';

      // Combine date + time into a scheduled DateTime
      DateTime? scheduledAt;
      if (_selectedDate != null && _selectedTime != null) {
        scheduledAt = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      }

      LatLng? finalLocation = _pickedLocation;
      final locationText = _locationController.text.trim();
      if (finalLocation == null && locationText.isNotEmpty) {
        try {
          final locations = await locationFromAddress(locationText);
          if (locations.isNotEmpty) {
            finalLocation = LatLng(locations[0].latitude, locations[0].longitude);
          }
        } catch (_) {
          // Fallback to null
        }
      }

      final newJob = JobPost(
        id: '',
        posterId: currentUser.uid,
        posterName: posterName,
        posterPhotoUrl: posterPhotoUrl,
        title: title,
        description: _descController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0.0,
        location: locationText,
        createdAt: DateTime.now(),
        scheduledAt: scheduledAt,
        jobLatitude: finalLocation?.latitude,
        jobLongitude: finalLocation?.longitude,
      );

      await JobService.createJobPost(newJob);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Post a Job',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Text(
              'Post a Job',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new job listing on the bulletin board',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 28),

            // ── Job Title ─────────────────────────────────────────────
            _buildTextField(
              controller: _titleController,
              label: 'Job Title',
              hint: 'e.g. Fix leaking pipe',
              icon: Icons.work_outline_rounded,
            ),
            const SizedBox(height: 16),

            // ── Description ───────────────────────────────────────────
            _buildTextField(
              controller: _descController,
              label: 'Description',
              hint: 'Describe what needs to be done...',
              icon: Icons.description_outlined,
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // ── Price & Location ──────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _priceController,
                    label: 'Price (RM)',
                    hint: 'e.g. 65',
                    icon: Icons.attach_money_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLocationField(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Schedule Date & Time ───────────────────────────────────
            Text(
              'Schedule (optional)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Date picker
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 18,
                              color: _selectedDate != null
                                  ? AppColors.primary
                                  : AppColors.textHint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                  : 'Pick date',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _selectedDate != null
                                    ? AppColors.textPrimary
                                    : AppColors.textHint,
                                fontWeight: _selectedDate != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Time picker
                Expanded(
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 18,
                              color: _selectedTime != null
                                  ? AppColors.primary
                                  : AppColors.textHint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedTime != null
                                  ? _selectedTime!.format(context)
                                  : 'Pick time',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _selectedTime != null
                                    ? AppColors.textPrimary
                                    : AppColors.textHint,
                                fontWeight: _selectedTime != null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Submit Button ─────────────────────────────────────────
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
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Post Job',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Location Field (with GPS button + Map pin button inline) ──────────────
  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _locationController,
          onChanged: (val) {
            if (_pickedLocation != null) {
              setState(() => _pickedLocation = null);
            }
          },
          decoration: InputDecoration(
            hintText: 'e.g. Remote, Melaka',
            hintStyle:
                GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
            prefixIcon: Icon(
              _pickedLocation != null
                  ? Icons.pin_drop_rounded
                  : Icons.location_on_outlined,
              color: _pickedLocation != null ? AppColors.primary : AppColors.textHint,
              size: 20,
            ),
            suffixIcon: _isLocating
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.my_location_rounded,
                            color: AppColors.primary, size: 20),
                        tooltip: 'Use current location',
                        onPressed: _getCurrentLocation,
                      ),
                      IconButton(
                        icon: Icon(
                          _pickedLocation != null
                              ? Icons.pin_drop_rounded
                              : Icons.map_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        tooltip: 'Pin on map',
                        onPressed: _pinOnMap,
                      ),
                    ],
                  ),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Generic Text Field ────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
            prefixIcon: maxLines == 1
                ? Icon(icon, color: AppColors.textHint, size: 20)
                : null,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
