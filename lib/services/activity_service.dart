import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Append-only usage/event log for internal data collection.
///
/// Each call writes ONE immutable row to `activity_events`. Never update or
/// delete these docs — they are the historical record used later to answer
/// questions like "jobs completed per technician last month", "average on-site
/// time", or "late arrivals". Live app state still lives in `jobs` /
/// `technicians`; this collection is purely additive history.
class ActivityService {
  static final CollectionReference<Map<String, dynamic>> _events =
      FirebaseFirestore.instance.collection('activity_events');

  /// Common event types. Kept as constants so call sites don't drift on spelling.
  static const String login = 'login';
  static const String logout = 'logout';
  static const String attendanceCheckin = 'attendance_checkin';
  static const String jobStart = 'job_start';
  static const String jobArrive = 'job_arrive';
  static const String jobFinish = 'job_finish';

  /// Records a single event. Writes are best-effort: analytics must never block
  /// or break the UI flow, so failures are logged and swallowed.
  static Future<void> log({
    required String type,
    String? technicianId,
    String? jobId,
    double? latitude,
    double? longitude,
    Map<String, dynamic> meta = const {},
  }) async {
    try {
      await _events.add({
        'type': type,
        'technicianId': technicianId,
        'jobId': jobId,
        'location': (latitude != null && longitude != null)
            ? GeoPoint(latitude, longitude)
            : null,
        'meta': meta,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ActivityService.log($type) error: $e');
    }
  }
}
