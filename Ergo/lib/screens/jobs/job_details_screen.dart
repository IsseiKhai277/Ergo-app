import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../theme/app_theme.dart';
import '../../models/job_post.dart';
import '../../services/chat_service.dart';
import '../messages/chat_screen.dart';
import 'location_picker_screen.dart';

class JobDetailsScreen extends StatefulWidget {
  final JobPost job;

  const JobDetailsScreen({super.key, required this.job});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final job = widget.job;

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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'RM ${job.price.toStringAsFixed(0)}',
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
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: AppColors.textSecondary),
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
                          const Icon(Icons.access_time,
                              size: 16, color: AppColors.textSecondary),
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
                                    job.posterName.isNotEmpty
                                        ? job.posterName[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.inter(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold),
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

          // Apply / Offer Button (Bottom fixed)
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
                  onPressed: () => _showOfferJobSheet(context),
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

  // ─── Offer Job Sheet ────────────────────────────────────────────────────────
  void _showOfferJobSheet(BuildContext context) {
    final job = widget.job;
    // Pre-populate with the listed job's details
    final titleController = TextEditingController(text: job.title);
    final descController = TextEditingController(text: job.description);
    final priceController =
        TextEditingController(text: job.price.toStringAsFixed(2));
    final locationController = TextEditingController(text: job.location);
    bool isLocating = false;
    bool isSubmitting = false;
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    // Map-picked coordinates — pre-fill from existing job if available
    LatLng? pickedLocation = (job.jobLatitude != null && job.jobLongitude != null)
        ? LatLng(job.jobLatitude!, job.jobLongitude!)
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> getCurrentLocation() async {
            setSheetState(() => isLocating = true);
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
                locationController.text =
                    address.replaceAll(RegExp(r',\s*$'), '');
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            } finally {
              setSheetState(() => isLocating = false);
            }
          }

          Future<void> pinOnMap() async {
            final result = await Navigator.push<LatLng?>(
              context,
              MaterialPageRoute(
                builder: (_) => LocationPickerScreen(
                  initialLocation: pickedLocation,
                ),
              ),
            );
            if (result != null) {
              setSheetState(() {
                pickedLocation = result;
                isLocating = true;
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
                  setSheetState(() {
                    locationController.text =
                        address.replaceAll(RegExp(r',\s*$'), '');
                  });
                } else {
                  setSheetState(() {
                    locationController.text =
                        '${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}';
                  });
                }
              } catch (_) {
                setSheetState(() {
                  locationController.text =
                      '${result.latitude.toStringAsFixed(4)}, ${result.longitude.toStringAsFixed(4)}';
                });
              } finally {
                setSheetState(() => isLocating = false);
              }
            }
          }

          Future<void> pickDate() async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? now,
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
            if (picked != null) setSheetState(() => selectedDate = picked);
          }

          Future<void> pickTime() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: selectedTime ?? TimeOfDay.now(),
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
            if (picked != null) setSheetState(() => selectedTime = picked);
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Apply for Job',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Send your application to ${job.posterName}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: titleController,
                          label: 'Job Title',
                          hint: 'e.g. Need a logo design',
                          icon: Icons.work_outline_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: descController,
                          label: 'Description',
                          hint: 'Describe what you need...',
                          icon: Icons.description_outlined,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: priceController,
                          label: 'Price (RM)',
                          hint: '0.00',
                          icon: Icons.attach_money_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        Column(
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
                              controller: locationController,
                              onChanged: (val) {
                                if (pickedLocation != null) {
                                  setSheetState(() => pickedLocation = null);
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'e.g. Remote, Melaka',
                                hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
                                prefixIcon: Icon(
                                  pickedLocation != null
                                      ? Icons.pin_drop_rounded
                                      : Icons.location_on_outlined,
                                  color: pickedLocation != null ? AppColors.primary : AppColors.textHint,
                                  size: 20,
                                ),
                                suffixIcon: isLocating
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
                                            onPressed: getCurrentLocation,
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              pickedLocation != null
                                                  ? Icons.pin_drop_rounded
                                                  : Icons.map_outlined,
                                              color: AppColors.primary,
                                              size: 20,
                                            ),
                                            tooltip: 'Pin on map',
                                            onPressed: pinOnMap,
                                          ),
                                        ],
                                      ),
                                filled: true,
                                fillColor: AppColors.surface,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Schedule Date & Time ──────────────────────────────
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
                                onTap: pickDate,
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
                                          color: selectedDate != null
                                              ? AppColors.primary
                                              : AppColors.textHint),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          selectedDate != null
                                              ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                                              : 'Pick date',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: selectedDate != null
                                                ? AppColors.textPrimary
                                                : AppColors.textHint,
                                            fontWeight: selectedDate != null
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
                                onTap: pickTime,
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
                                          color: selectedTime != null
                                              ? AppColors.primary
                                              : AppColors.textHint),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          selectedTime != null
                                              ? selectedTime!.format(context)
                                              : 'Pick time',
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: selectedTime != null
                                                ? AppColors.textPrimary
                                                : AppColors.textHint,
                                            fontWeight: selectedTime != null
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final title = titleController.text.trim();
                            if (title.isEmpty) return;

                            setSheetState(() => isSubmitting = true);

                            try {
                              final price =
                                  double.tryParse(priceController.text) ?? 0.0;

                              // Combine date + time into a scheduled DateTime
                              DateTime? scheduledAt;
                              if (selectedDate != null &&
                                  selectedTime != null) {
                                scheduledAt = DateTime(
                                  selectedDate!.year,
                                  selectedDate!.month,
                                  selectedDate!.day,
                                  selectedTime!.hour,
                                  selectedTime!.minute,
                                );
                              }

                              // Create or reuse conversation with the job poster
                              final convId =
                                  await ChatService.getOrCreateConversation(
                                      job.posterId);

                              // Send job offer message
                              await ChatService.sendJobOffer(
                                conversationId: convId,
                                otherUserId: job.posterId,
                                title: title,
                                description: descController.text.trim(),
                                price: price,
                                location: locationController.text.trim(),
                                scheduledAt: scheduledAt,
                                jobLatitude: pickedLocation?.latitude,
                                jobLongitude: pickedLocation?.longitude,
                              );

                              if (!context.mounted) return;
                              Navigator.pop(context); // Close sheet

                              // Navigate to the chat
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    conversationId: convId,
                                    otherUserId: job.posterId,
                                    otherUserName: job.posterName,
                                    otherUserPhotoUrl: job.posterPhotoUrl,
                                    otherUserRole: '',
                                  ),
                                ),
                              );
                            } catch (e) {
                              setSheetState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Send Application',
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
          );
        },
      ),
    );
  }

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
