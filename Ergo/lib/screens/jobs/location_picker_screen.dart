import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

/// Full-screen map that lets the user pick a location by dragging the map.
///
/// The pin is fixed in the center of the screen. As the user drags the map,
/// [onPositionChanged] updates [_selected] to the new center.
///
/// Returns a [LatLng] when the user presses "Confirm Location",
/// or null if they dismiss without confirming.
class LocationPickerScreen extends StatefulWidget {
  /// Initial center for the map (e.g. user's GPS position or Malaysia default).
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const LatLng _defaultCenter = LatLng(3.1390, 101.6869); // KL

  late final MapController _mapController;
  LatLng _selected = const LatLng(3.1390, 101.6869);
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selected = widget.initialLocation ?? _defaultCenter;
    // Attempt to get GPS position on open.
    _goToCurrentLocation(silent: true);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _goToCurrentLocation({bool silent = false}) async {
    if (!silent) setState(() => _locating = true);
    final pos = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;
    if (pos != null) {
      _mapController.move(pos, 16);
      setState(() => _selected = pos);
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get current location.')),
      );
    }
    if (!silent && mounted) setState(() => _locating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── App Bar ────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context, null),
        ),
        title: Text(
          'Pin Job Location',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 15,
              onPositionChanged: (position, _) {
                if (position.center != null) {
                  setState(() => _selected = position.center!);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ergo.app',
              ),
            ],
          ),

          // ── Center crosshair pin ───────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.primary,
                  size: 48,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 6)],
                ),
                // Drop shadow "stem" spacer to simulate pin depth
                const SizedBox(height: 0),
              ],
            ),
          ),

          // ── Coordinate chip ────────────────────────────────────────────────
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  '${_selected.latitude.toStringAsFixed(5)}, '
                  '${_selected.longitude.toStringAsFixed(5)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // ── GPS FAB ────────────────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'location_gps',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _locating ? null : () => _goToCurrentLocation(),
              tooltip: 'Use my current location',
              child: _locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(
                      Icons.my_location_rounded,
                      color: AppColors.primary,
                    ),
            ),
          ),

          // ── Confirm Button ─────────────────────────────────────────────────
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _selected),
                icon: const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  'Confirm Location',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
