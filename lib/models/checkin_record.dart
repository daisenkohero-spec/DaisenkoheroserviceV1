class CheckinRecord {
  final DateTime date;        // วันที่
  final DateTime checkinTime; // เวลาเข้างานจริง
  final String type;          // normal / late / leave
  final String reason;        // เหตุผล

  CheckinRecord({
    required this.date,
    required this.checkinTime,
    required this.type,
    required this.reason,
  });
}
