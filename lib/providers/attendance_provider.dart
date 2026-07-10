import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/activity_service.dart';

/// ================= ENUM =================

enum WeekStatus { present, late, leave, absent, upcoming }

enum CheckinType { normal, late, leave }

/// ================= MODEL =================

class AttendanceRecord {
  final DateTime date;
  final WeekStatus status;
  final TimeOfDay checkinTime;
  final String? reason;

  AttendanceRecord({
    required this.date,
    required this.status,
    required this.checkinTime,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      "date": date.toIso8601String(),
      "status": status.name,
      "checkin_time":
          "${checkinTime.hour.toString().padLeft(2, '0')}:${checkinTime.minute.toString().padLeft(2, '0')}",
      "reason": reason,
    };
  }
}

class WeekDayData {
  final String day;
  final int date;
  final WeekStatus status;

  WeekDayData({required this.day, required this.date, required this.status});
}

/// ================= PROVIDER =================

class AttendanceProvider extends ChangeNotifier {
  final Map<DateTime, AttendanceRecord> _records = {};

  Map<DateTime, AttendanceRecord> get records => _records;
  double? _lastDistance;
  double? get lastDistance => _lastDistance;

  // ตำแหน่งจริงล่าสุด (เก็บไว้เพื่อบันทึกลง activity_events)
  double? _lastLat;
  double? _lastLng;

  // ================= STATUS COLORS  =================

  Color getStatusColor(WeekStatus status) {
    switch (status) {
      case WeekStatus.present:
        return Colors.green;
      case WeekStatus.late:
        return Colors.orange;
      case WeekStatus.leave:
        return const Color(0xFF6366F1);
      case WeekStatus.absent:
        return Colors.red;
      case WeekStatus.upcoming:
      default:
        return Colors.grey;
    }
  }

  Color getStatusBgColor(WeekStatus status) {
    switch (status) {
      case WeekStatus.present:
        return const Color(0xFFD1FAE5);
      case WeekStatus.late:
        return const Color(0xFFFEF3C7);
      case WeekStatus.leave:
        return const Color(0xFFE0E7FF);
      case WeekStatus.absent:
        return const Color(0xFFFECACA);
      case WeekStatus.upcoming:
      default:
        return const Color(0xFFE5E7EB);
    }
  }
  // ================= GET STATUS BY DATE =================

  WeekStatus? getStatus(DateTime date) {
    final now = DateTime.now();

    final normalized = DateTime(date.year, date.month, date.day);

    final normalizedToday = DateTime(now.year, now.month, now.day);

    if (_records.containsKey(normalized)) {
      return _records[normalized]!.status;
    }

    if (normalized.isAfter(normalizedToday)) {
      return WeekStatus.upcoming;
    }

    if (normalized.isBefore(normalizedToday)) {
  return WeekStatus.absent;
}

    return null;
  }

  // ================= CHECK-IN =================
  Future<void> checkIn({
    required CheckinType type,
    String? reason,
    String? technicianId,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ป้องกันเช็คอินซ้ำ
    if (_records.containsKey(today)) {
      return;
    }

    WeekStatus status;

    if (type == CheckinType.leave) {
      status = WeekStatus.leave;
    } else {
      final eightAM = DateTime(now.year, now.month, now.day, 8, 0);

      if (now.isAfter(eightAM)) {
        status = WeekStatus.late;
      } else {
        status = WeekStatus.present;
      }
    }

    final record = AttendanceRecord(
      date: today,
      status: status,
      checkinTime: TimeOfDay.now(),
      reason: reason,
    );

    _records[today] = record;
    notifyListeners();

    // บันทึกลง activity_events แบบถาวร (append-only) เพื่อเก็บข้อมูลการเข้างาน
    final isLeave = type == CheckinType.leave;
    await ActivityService.log(
      type: ActivityService.attendanceCheckin,
      technicianId: technicianId,
      // ตำแหน่งจะมีเฉพาะการเข้างานจริง (normal/late) ไม่ใช่การลา
      latitude: isLeave ? null : _lastLat,
      longitude: isLeave ? null : _lastLng,
      meta: {
        'status': status.name, // present | late | leave
        'checkinType': type.name, // normal | late | leave
        'checkinTime': record.toJson()['checkin_time'],
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (!isLeave && _lastDistance != null) 'distanceM': _lastDistance,
      },
    );
  }
  // ================= LOCATION CHECK =================

  Future<double> getDistanceFromOffice() async {
    bool serviceEnabled;
    LocationPermission permission;

    /// เปิด location ไหม
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("กรุณาเปิด GPS");
    }

    /// ขอ permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied");
      }
    }

    /// ดึงตำแหน่งปัจจุบันจริง
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );

    debugPrint("CURRENT LAT: ${position.latitude}");
    debugPrint("CURRENT LNG: ${position.longitude}");

    _lastLat = position.latitude;
    _lastLng = position.longitude;

    double distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      officeLat,
      officeLng,
    );

    _lastDistance = distance;
    notifyListeners();

    return distance;
  }

  // ================= TODAY RECORD =================

  AttendanceRecord? getTodayRecord() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _records[today];
  }

  AttendanceRecord? get todayRecord => getTodayRecord();
  // ================= OFFICE LOCATION =================

  static const double officeLat = 13.987401;
  static const double officeLng = 100.604224;
// TODO: ช่วงทดลองใช้เดือนแรก ตั้งรัศมีกว้างไว้ให้เช็คอินได้จากทุกที่
// เมื่อใช้งานจริงที่ออฟฟิศแล้ว ให้ปรับกลับเป็น 100 (เมตร)
static const double allowedRadius = 50000; // 50 km (pilot/testing)
  // ================= WEEK VIEW =================

  List<WeekDayData> getThisWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    List<WeekDayData> week = [];

    for (int i = 0; i < 7; i++) {
      final date = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day + i,
      );

      final record = _records[date];

      WeekStatus status;

      if (record != null) {
        status = record.status;
      } else if (date.isAfter(today)) {
        status = WeekStatus.upcoming;
      } else if (date.isAtSameMomentAs(today)) {
        status = WeekStatus.upcoming;
      } else {
        status = WeekStatus.absent;
      }

      week.add(
        WeekDayData(
          day: _weekdayName(date.weekday),
          date: date.day,
          status: status,
        ),
      );
    }

    return week;
  }

  String _weekdayName(int weekday) {
    const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    if (weekday < 1 || weekday > 7) return "";
    return names[weekday - 1];
  }

  String formatDistance(double distanceInMeters) {
  if (distanceInMeters <= 1000) {
    return "${distanceInMeters.toStringAsFixed(0)} m";
  } else {
    double km = distanceInMeters / 1000;
    return "${km.toStringAsFixed(1)} km";
  }
}
  // ================= STATS =================

  int getMonthlyPresentCount() {
    final now = DateTime.now();

    return _records.values
        .where(
          (r) =>
              r.date.month == now.month &&
              r.date.year == now.year &&
              (r.status == WeekStatus.present || r.status == WeekStatus.late),
        )
        .length;
  }

 int getMonthlyAttendancePercent() {
  final now = DateTime.now();

  final totalDays = now.day;

  if (totalDays == 0) return 0;

  final presentCount = getMonthlyPresentCount();

  return ((presentCount / totalDays) * 100).round();
}

  // ================= CLEAR =================

  void clearAll() {
    _records.clear();
    notifyListeners();
  }
}
