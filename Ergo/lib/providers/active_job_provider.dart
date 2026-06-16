import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/job_post.dart';
import '../services/job_service.dart';

/// Listens to the worker's currently active job in Firestore and exposes it
/// to the widget tree via Provider. [MainScreen] uses this to show/hide the
/// global "Back to Job" floating button.
class ActiveJobProvider extends ChangeNotifier {
  StreamSubscription<JobPost?>? _workerSub;
  StreamSubscription<JobPost?>? _clientSub;
  JobPost? _activeJob;
  JobPost? _activeClientJob;

  JobPost? get activeJob => _activeJob;
  JobPost? get activeClientJob => _activeClientJob;
  bool get hasActiveJob => _activeJob != null;
  bool get hasActiveClientJob => _activeClientJob != null;

  ActiveJobProvider() {
    _startListening();
  }

  void _startListening() {
    _workerSub = JobService.activeWorkerJobStream.listen(
      (job) {
        _activeJob = job;
        notifyListeners();
      },
      onError: (_) {
        _activeJob = null;
        notifyListeners();
      },
    );

    _clientSub = JobService.activeClientJobStream.listen(
      (job) {
        _activeClientJob = job;
        notifyListeners();
      },
      onError: (_) {
        _activeClientJob = null;
        notifyListeners();
      },
    );
  }

  void refresh() {
    _workerSub?.cancel();
    _clientSub?.cancel();
    _startListening();
  }

  @override
  void dispose() {
    _workerSub?.cancel();
    _clientSub?.cancel();
    super.dispose();
  }
}
