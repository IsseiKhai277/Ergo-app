import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../services/chat_service.dart';
import '../messages/chat_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import '../jobs/location_picker_screen.dart';
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        final data = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        final fullName = data['fullName'] ?? data['name'] ?? 'Unknown User';
        final email = data['email'] ?? '';
        final photoUrl = data['photoUrl'] ?? data['photoURL'] ?? '';
        final role = data['role'] ?? '';
        final skills = List<String>.from(data['skills'] ?? []);
        final phone = data['phoneNumber'] ?? '';
        final isVerified = data['isVerified'] ?? false;
        final completion = (data['completionPercentage'] ?? 0) as int;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              // ── App Bar ────────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.primary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeader(
                    fullName: fullName,
                    email: email,
                    photoUrl: photoUrl,
                    role: role,
                    isVerified: isVerified,
                    completion: completion,
                  ),
                ),
              ),

              // ── Body ───────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('reviews')
                            .where('userId', isEqualTo: widget.userId)
                            .snapshots(),
                        builder: (context, reviewsSnap) {
                          double dynamicRating = 0.0;
                          int dynamicReviewCount = 0;

                          if (reviewsSnap.hasData && reviewsSnap.data!.docs.isNotEmpty) {
                            final docs = reviewsSnap.data!.docs;
                            double totalRating = 0.0;
                            for (final doc in docs) {
                              final rData = doc.data() as Map<String, dynamic>? ?? {};
                              totalRating += (rData['rating'] ?? 0.0).toDouble();
                            }
                            dynamicReviewCount = docs.length;
                            dynamicRating = totalRating / dynamicReviewCount;
                          }

                          return _buildRatingCard(dynamicRating, dynamicReviewCount);
                        },
                      ),
                      const SizedBox(height: 16),

                      // Skills
                      if (skills.isNotEmpty) ...[
                        _buildSkillsCard(skills),
                        const SizedBox(height: 16),
                      ],

                      // Contact
                      _buildContactCard(email, phone),
                      const SizedBox(height: 16),

                      // Offer Job Button
                      _buildOfferJobButton(fullName, photoUrl, role),
                      const SizedBox(height: 16),

                      // Posts
                      _buildPostsSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader({
    required String fullName,
    required String email,
    required String photoUrl,
    required String role,
    required bool isVerified,
    required int completion,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 46,
                backgroundColor: Colors.white.withOpacity(0.2),
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _buildStatusBadge(isVerified),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CircularPercentIndicator(
                radius: 36,
                lineWidth: 5,
                percent: completion / 100,
                center: Text(
                  '$completion%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                progressColor: const Color(0xFF4ADE80),
                backgroundColor: Colors.white.withOpacity(0.25),
                circularStrokeCap: CircularStrokeCap.round,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified
            ? const Color(0xFF16A34A).withOpacity(0.2)
            : const Color(0xFFDC2626).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVerified
              ? const Color(0xFF4ADE80).withOpacity(0.5)
              : const Color(0xFFFCA5A5).withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified_rounded : Icons.warning_amber_rounded,
            size: 13,
            color: isVerified ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
          ),
          const SizedBox(width: 5),
          Text(
            isVerified ? 'Verified' : 'Unverified',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isVerified ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Rating Card ───────────────────────────────────────────────────────────
  Widget _buildRatingCard(double rating, int reviewCount) {
    return _card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rating == 0.0 ? 'No ratings yet' : rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (rating > 0)
                  RatingBarIndicator(
                    rating: rating,
                    itemBuilder: (_, __) =>
                        const Icon(Icons.star_rounded, color: Color(0xFFFBBF24)),
                    itemCount: 5,
                    itemSize: 16,
                  ),
                Text(
                  '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Skills Card ───────────────────────────────────────────────────────────
  Widget _buildSkillsCard(List<String> skills) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skills',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  skill,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Contact Card ──────────────────────────────────────────────────────────
  Widget _buildContactCard(String email, String phone) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (email.isNotEmpty)
            _contactRow(Icons.email_rounded, 'Email', email),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            _contactRow(Icons.phone_rounded, 'Phone', phone),
          ],
          if (email.isEmpty && phone.isEmpty)
            Text(
              'No contact information provided.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Posts Section ─────────────────────────────────────────────────────────
  Widget _buildPostsSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Posts',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('userId', isEqualTo: widget.userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.error));
              }
              final docs = snapshot.data?.docs ?? [];
              docs.sort((a, b) {
                final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime);
              });
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'No posts yet.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              return ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.outline, height: 1),
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final imageUrls = List<String>.from(d['imageUrls'] ?? []);
                  final caption = (d['caption'] ?? '') as String;
                  final createdAt =
                      (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final likeCount = d['likeCount'] ?? 0;
                  final commentCount = d['commentCount'] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageUrls.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _decodeImage(imageUrls.first),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (caption.isNotEmpty)
                          Text(
                            caption,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.favorite_border,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text('$likeCount',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 12),
                            const Icon(Icons.chat_bubble_outline,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text('$commentCount',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: AppColors.textSecondary)),
                            const Spacer(),
                            Text(
                              timeago.format(createdAt),
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Offer Job ─────────────────────────────────────────────────────────────
  Widget _buildOfferJobButton(String fullName, String photoUrl, String role) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () => _showOfferJobSheet(context, fullName, photoUrl, role),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.work_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Offer Job to $fullName',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showOfferJobSheet(BuildContext context, String fullName, String photoUrl, String role) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final locationController = TextEditingController();
    bool isLocating = false;
    bool isSubmitting = false;
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    LatLng? pickedLocation;

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
                setSheetState(() {
                  locationController.text =
                      address.replaceAll(RegExp(r',\s*$'), '');
                  pickedLocation = LatLng(position.latitude, position.longitude);
                });
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
                  'Offer a Job',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Send a direct job offer to $fullName',
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
                        // ── Schedule Date & Time ──────────────────────────
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
                              final price = double.tryParse(priceController.text) ?? 0.0;

                              // Combine date + time into a scheduled DateTime
                              DateTime? scheduledAt;
                              if (selectedDate != null && selectedTime != null) {
                                scheduledAt = DateTime(
                                  selectedDate!.year,
                                  selectedDate!.month,
                                  selectedDate!.day,
                                  selectedTime!.hour,
                                  selectedTime!.minute,
                                );
                              }

                              // Create conversation
                              final convId = await ChatService.getOrCreateConversation(widget.userId);
                              
                              LatLng? finalLocation = pickedLocation;
                              final locationText = locationController.text.trim();
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

                              // Send job offer message
                              await ChatService.sendJobOffer(
                                conversationId: convId,
                                otherUserId: widget.userId,
                                title: title,
                                description: descController.text.trim(),
                                price: price,
                                location: locationText,
                                scheduledAt: scheduledAt,
                                jobLatitude: finalLocation?.latitude,
                                jobLongitude: finalLocation?.longitude,
                              );

                              if (!context.mounted) return;
                              Navigator.pop(context); // Close sheet
                              
                              // Navigate to chat
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    conversationId: convId,
                                    otherUserId: widget.userId,
                                    otherUserName: fullName,
                                    otherUserPhotoUrl: photoUrl,
                                    otherUserRole: role,
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
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Send Offer',
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
            hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
            prefixIcon: maxLines == 1 ? Icon(icon, color: AppColors.textHint, size: 20) : null,
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
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
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
      child: child,
    );
  }

  Widget _decodeImage(String source) {
    try {
      if (source.startsWith('http')) {
        return Image.network(source,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink());
      } else {
        return Image.memory(base64Decode(source),
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink());
      }
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}
