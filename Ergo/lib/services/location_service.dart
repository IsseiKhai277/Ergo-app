import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Singleton service that manages GPS location permission and real-time
/// worker tracking. Tracking writes to Firestore every 7 seconds using a
/// [Timer.periodic] so we have exact control over update frequency.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Timer? _trackingTimer;
  String? _activeJobId;

  // ─── Permission ──────────────────────────────────────────────────────────────

  /// Requests location permission and returns true if granted.
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ─── Current Position ────────────────────────────────────────────────────────

  /// Returns the device's current GPS position as a [LatLng].
  Future<LatLng?> getCurrentPosition() async {
    final granted = await requestPermission();
    if (!granted) return null;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  // ─── Tracking ────────────────────────────────────────────────────────────────

  /// Starts a periodic 7-second timer that writes the worker's current
  /// coordinates to `jobs/{jobId}` in Firestore.
  Future<void> startTracking(String jobId) async {
    // Stop any previous session first.
    stopTracking();

    final granted = await requestPermission();
    if (!granted) return;

    _activeJobId = jobId;

    // Write immediately, then every 7 seconds.
    await _writePosition(jobId);
    _trackingTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      _writePosition(jobId);
    });
  }

  Future<void> _writePosition(String jobId) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'workerLatitude': pos.latitude,
        'workerLongitude': pos.longitude,
        'workerLastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Silently ignore position errors during background updates.
    }
  }

  /// Cancels the periodic tracking timer.
  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _activeJobId = null;
  }

  // ─── Clear Worker Location ───────────────────────────────────────────────────

  /// Deletes the three worker location fields from the job document.
  /// Called when the worker presses "Arrived".
  Future<void> clearWorkerLocation(String jobId) async {
    stopTracking();
    await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
      'workerLatitude': FieldValue.delete(),
      'workerLongitude': FieldValue.delete(),
      'workerLastUpdated': FieldValue.delete(),
    });
  }

  // ─── Getters ─────────────────────────────────────────────────────────────────

  bool get isTracking => _trackingTimer != null;
  String? get activeJobId => _activeJobId;
}
