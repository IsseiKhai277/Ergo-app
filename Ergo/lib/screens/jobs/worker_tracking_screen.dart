import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import '../../models/job_post.dart';
import '../../theme/app_theme.dart';

class WorkerTrackingScreen extends StatefulWidget {
  final JobPost job;

  const WorkerTrackingScreen({super.key, required this.job});

  @override
  State<WorkerTrackingScreen> createState() => _WorkerTrackingScreenState();
}

class _WorkerTrackingScreenState extends State<WorkerTrackingScreen> {
  late final MapController _mapController;
  List<LatLng> _routePoints = [];
  LatLng? _lastFetchedWorkerPos;
  bool _fetchingRoute = false;
  bool _hasInitialCentered = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // Fetch route geometry from OSRM and decode using flutter_polyline_points
  Future<void> _fetchRoute(LatLng workerPos, LatLng jobPos) async {
    if (_fetchingRoute) return;
    _fetchingRoute = true;
    _lastFetchedWorkerPos = workerPos;

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${workerPos.longitude},${workerPos.latitude};'
        '${jobPos.longitude},${jobPos.latitude}'
        '?overview=full&geometries=polyline',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final encodedPolyline = data['routes'][0]['geometry'] as String;
          final polylinePoints = PolylinePoints();
          final decoded = polylinePoints.decodePolyline(encodedPolyline);

          if (mounted) {
            setState(() {
              _routePoints = decoded
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList();
            });
          }
        }
      } else {
        // Fallback to direct line if OSRM request failed
        if (mounted) {
          setState(() {
            _routePoints = [workerPos, jobPos];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
      if (mounted && _routePoints.isEmpty) {
        setState(() {
          _routePoints = [workerPos, jobPos];
        });
      }
    } finally {
      _fetchingRoute = false;
    }
  }

  // Fits camera to include both points with padding
  void _fitMapBounds(LatLng workerPos, LatLng jobPos) {
    if (!mounted) return;
    final bounds = LatLngBounds(workerPos, jobPos);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.job.id)
            .snapshots(),
        builder: (context, snapshot) {
          LatLng? workerPos;
          JobPost currentJob = widget.job;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data();
            if (data != null) {
              currentJob = JobPost.fromMap(data, snapshot.data!.id);
              if (currentJob.workerLatitude != null &&
                  currentJob.workerLongitude != null) {
                workerPos = LatLng(
                  currentJob.workerLatitude!,
                  currentJob.workerLongitude!,
                );
              }
            }
          }

          // Target location of the job (using live snapshot data)
          final LatLng destinationPos = LatLng(
            currentJob.jobLatitude ?? 3.1390,
            currentJob.jobLongitude ?? 101.6869,
          );

          // Trigger route fetch when worker position changes or is initially loaded
          if (workerPos != null &&
              (workerPos != _lastFetchedWorkerPos || _routePoints.isEmpty)) {
            _fetchRoute(workerPos, destinationPos);
          }

          // Auto center bounds only once on initial data fetch
          if (workerPos != null && !_hasInitialCentered) {
            _hasInitialCentered = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitMapBounds(workerPos!, destinationPos);
            });
          }

          return Stack(
            children: [
              // ── Map Layer ──────────────────────────────────────────────────
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: workerPos ?? destinationPos,
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ergo.app',
                  ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 4.5,
                          color: const Color(0xFF2563EB), // Sleek blue path
                          borderColor: Colors.white,
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      // Destination Marker
                      Marker(
                        point: destinationPos,
                        width: 50,
                        height: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              bottom: 0,
                              child: Container(
                                width: 8,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.work_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Worker Marker
                      if (workerPos != null)
                        Marker(
                          point: workerPos,
                          width: 80,
                          height: 80,
                          child: PulsatingWorkerMarker(
                            photoUrl: currentJob.workerPhotoUrl,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // ── Custom Gradient App Bar Over Map ───────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 16,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Track Worker',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              currentJob.title,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Floating Action Buttons (GPS & Center Bounds) ────────────────
              Positioned(
                right: 16,
                bottom: 220,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'center_bounds',
                      mini: true,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2563EB),
                      child: const Icon(Icons.zoom_out_map_rounded),
                      onPressed: () {
                        if (workerPos != null) {
                          _fitMapBounds(workerPos, destinationPos);
                        } else {
                          _mapController.move(destinationPos, 15);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // ── Bottom Info Panel Overlay ──────────────────────────────────
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEFF6FF),
                          border: Border.all(
                            color: const Color(0xFFDBEAFE),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(27),
                          child: currentJob.workerPhotoUrl.isNotEmpty
                              ? Image.network(
                                  currentJob.workerPhotoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                    Icons.person_outline_rounded,
                                    color: Color(0xFF2563EB),
                                    size: 28,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_outline_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 28,
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentJob.workerName.isNotEmpty
                                  ? currentJob.workerName
                                  : 'Worker Assigned',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF3B82F6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'On their way',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: const Color(0xFF3B82F6),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Pulsating Worker Marker Component ──────────────────────────────────────
class PulsatingWorkerMarker extends StatefulWidget {
  final String? photoUrl;

  const PulsatingWorkerMarker({super.key, this.photoUrl});

  @override
  State<PulsatingWorkerMarker> createState() => _PulsatingWorkerMarkerState();
}

class _PulsatingWorkerMarkerState extends State<PulsatingWorkerMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Three nested delayed pulsating rings
            _buildPulseCircle(0.0),
            _buildPulseCircle(0.33),
            _buildPulseCircle(0.66),
            // Custom avatar inside pin
            _buildAvatarPin(),
          ],
        );
      },
    );
  }

  Widget _buildPulseCircle(double delayOffset) {
    final value = (_controller.value + delayOffset) % 1.0;
    // Scale starts from 0.8 (behind the avatar) up to 2.2x
    final scale = 0.6 + (value * 1.6);
    // Opacity fades out as it expands
    final opacity = (1.0 - value).clamp(0.0, 1.0);

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity * 0.45,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2563EB).withValues(alpha: 0.45),
            border: Border.all(
              color: const Color(0xFF3B82F6),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPin() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pin shadow
        Positioned(
          bottom: 4,
          child: Container(
            width: 14,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
        ),
        // Pin body
        Container(
          width: 52,
          height: 52,
          margin: const EdgeInsets.only(bottom: 12),
          child: CustomPaint(
            painter: _PinPainter(color: const Color(0xFF2563EB)),
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(1.5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                      ? Image.network(
                          widget.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.person,
                            color: Color(0xFF2563EB),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Color(0xFF2563EB),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PinPainter extends CustomPainter {
  final Color color;

  _PinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;

    // Draw the pinpoint drop shape: a circle on top pointing to the center bottom
    path.moveTo(width / 2, height);
    path.cubicTo(
      width * 0.08,
      height * 0.65,
      0,
      width * 0.72,
      0,
      width / 2,
    );
    path.arcTo(
      Rect.fromLTWH(0, 0, width, width),
      3.14159,
      3.14159,
      false,
    );
    path.cubicTo(
      width,
      width * 0.72,
      width * 0.92,
      height * 0.65,
      width / 2,
      height,
    );
    path.close();

    canvas.drawPath(path, paint);

    // Draw a small border/stroke
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
