import 'package:cloud_firestore/cloud_firestore.dart';

/// สถานะงาน (ดูสเปก AIR-D Hero Service v1 ส่วน "สถานะงาน")
///
/// เส้นทางหลัก: pendingPayment → dispatching → assigned → traveling → working
/// → (quotePending สำหรับงานซ่อม) → completed → closed
///
/// `wire` คือค่าที่เก็บใน Firestore (snake_case ตามสเปก)
/// "เลยกำหนดเวลา" ไม่ใช่สถานะ: คำนวณจาก endTime ดู [Job.isOverdue]
enum JobStatus {
  pendingPayment('pending_payment'), // รอลูกค้าชำระเงิน (ล็อกช่วงเวลา 15 นาที)
  paymentReview('payment_review'), // สลิปตรวจไม่ผ่าน รอแอดมินตัดสิน
  dispatching('dispatching'), // จ่ายแล้ว กำลังหาช่าง
  assigned('assigned'), // ได้ช่างแล้ว (กดรับเองหรือแอดมินมอบหมาย)
  traveling('traveling'), // ช่างกำลังเดินทาง (ลูกค้าเห็นตำแหน่งสด)
  working('working'), // ถึงหน้างาน / กำลังทำงาน
  quotePending('quote_pending'), // งานซ่อม: รออนุมัติใบเสนอราคา
  completed('completed'), // ช่างกดเสร็จงาน
  closed('closed'), // ลูกค้ายืนยัน หรือครบ 24 ชม.
  cancelled('cancelled'),
  expired('expired'); // ไม่ชำระภายในเวลาที่ล็อกไว้

  const JobStatus(this.wire);
  final String wire;

  /// ค่าเก่าที่เคยเก็บใน Firestore ก่อนระบบจอง
  /// - pending / accepted: งานที่แอดมินมอบหมายให้ช่างแล้ว = assigned
  /// - overdue: เลยเวลาคำนวณจาก endTime แทน จึงกลับเป็น assigned
  static const Map<String, JobStatus> _legacy = {
    'pending': JobStatus.assigned,
    'accepted': JobStatus.assigned,
    'overdue': JobStatus.assigned,
  };

  static JobStatus fromWire(Object? value) {
    final v = (value ?? '').toString().trim().toLowerCase();
    for (final s in JobStatus.values) {
      if (s.wire == v || s.name.toLowerCase() == v) return s;
    }
    return _legacy[v] ?? JobStatus.assigned;
  }

  /// งานจบฝั่งช่างแล้ว (นับเป็นงานเสร็จในแอปช่าง)
  bool get isDone => this == completed || this == closed;

  /// สถานะที่แสดงในแอปช่าง (งานที่ยกเลิก/หมดอายุไม่ต้องแสดง)
  bool get visibleToTechnician =>
      this != cancelled && this != expired && this != pendingPayment &&
      this != paymentReview && this != dispatching;
}

enum JobNotificationType {
  none,
  newJob,
  jobUpdate,
  reminder,
  rescheduled,
  cancelled,
}

enum JobPriority { low, normal, high, urgent }

class Job {
  String id;
  String date;
  String month;
  String start;
  String end;

  String service;
  String customer;
  String phone;

  String place;
  String? mapUrl;

  String? customerNote;
  final String location;
  final String serviceType;
  final String? note;

  DateTime createdAt;
  DateTime startTime;
  final DateTime endTime;
  String technicianId;

  JobStatus status;
  JobNotificationType notificationType;
  JobPriority priority;

  bool isNotificationRead;

  DateTime? startTravel;
  DateTime? arrivedAt;
  DateTime? updatedAt;
  DateTime? startedWorkingAt;
  DateTime? finishedAt;

  String? imagePath;

  Job({
    required this.id,
    required this.date,
    required this.month,
    required this.start,
    required this.end,
    required this.service,
    required this.customer,
    required this.phone,
    required this.place,
    required this.location,
    required this.serviceType,
    this.note,
    this.mapUrl,
    this.customerNote,
    required this.createdAt,
    required this.startTime,
    required this.endTime,
    this.updatedAt,
    required this.technicianId,
    this.status = JobStatus.assigned,
    this.notificationType = JobNotificationType.none,
    this.priority = JobPriority.normal,
    this.isNotificationRead = false,
    this.startTravel,
    this.arrivedAt,
    this.startedWorkingAt,
    this.finishedAt,
    this.imagePath,
  });
  bool get isDone => status.isDone;

  /// เลยเวลานัดแล้วแต่งานยังไม่จบ (คำนวณ ไม่ได้เก็บเป็นสถานะ)
  bool get isOverdue => !isDone && endTime.isBefore(DateTime.now());

  // ==============================
  // Firestore -> Model
  // ==============================
  factory Job.fromFirestore(Map<String, dynamic> json, String id) {
  
    return Job(
      id: id,
      date: json['date'] ?? '',
      month: json['month'] ?? '',
      start: json['start'] ?? '',
      end: json['end'] ?? '',
      service: json['service'] ?? '',
      customer: (json['customer'] ?? json['customer'] ??'').toString().trim(),
      phone: (json['phone'] ?? '').toString().trim(),
      place: json['place'] ?? '',
      location: json['location'] ?? json['place'] ?? '',
      serviceType: json['serviceType'] ?? json['service'] ?? '',
      note: json['note'] ?? json['customerNote'],
      mapUrl: json['mapUrl'],
      customerNote: json['customerNote'],
      endTime: json['endTime'] is Timestamp
          ? (json['endTime'] as Timestamp).toDate()
          : DateTime.tryParse(json['endTime'] ?? '') ?? DateTime.now(),
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),

      //  string + timestamp
      startTime: json['startTime'] is Timestamp
          ? (json['startTime'] as Timestamp).toDate()
          : DateTime.tryParse(json['startTime'] ?? '') ?? DateTime.now(),

      technicianId: json['technicianId'] ?? '',

      status: JobStatus.fromWire(json['status']),

      notificationType: JobNotificationType.values.firstWhere(
        (e) => e.name == (json['notificationType'] ?? 'none'),
        orElse: () => JobNotificationType.none,
      ),

      priority: JobPriority.values.firstWhere(
        (e) => e.name == (json['priority'] ?? 'normal'),
        orElse: () => JobPriority.normal,
      ),

      isNotificationRead: json['isNotificationRead'] ?? false,

      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,

      startedWorkingAt: json['startedWorkingAt'] is Timestamp
          ? (json['startedWorkingAt'] as Timestamp).toDate()
          : null,

      finishedAt: json['finishedAt'] is Timestamp
          ? (json['finishedAt'] as Timestamp).toDate()
          : null,

      imagePath: json['imagePath'],
    );
  }
  // ==============================
  // Model -> JSON (send to API)
  // ==============================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'month': month,
      'start': start,
      'end': end,
      'service': service,
      'customer': customer,
      'phone': phone,
      'place': place,
      "location": location,
      "serviceType": serviceType,
      "note": note,
      'mapUrl': mapUrl,
      'customerNote': customerNote,
      'createdAt': createdAt.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'technicianId': technicianId,
      'status': status.wire,
      'notificationType': notificationType.name,
      'priority': priority.name,
      'isNotificationRead': isNotificationRead,
      'startTravel': startTravel?.toIso8601String(),
      'arrivedAt': arrivedAt?.toIso8601String(),
      'startedWorkingAt': startedWorkingAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'imagePath': imagePath,
    };
  }

  // ==============================
  // Firestore Map
  // ==============================
  Map<String, dynamic> toMap() {
    return {
      "date": date,
      "month": month,
      "start": start,
      "end": end,
      "service": service,
      "customer": customer,
      "phone": phone,
      "place": place,
      "mapUrl": mapUrl,
      "customerNote": customerNote,
      "location": location,
      "serviceType": serviceType,
      "note": note,

      "createdAt": Timestamp.fromDate(createdAt),
      "startTime": Timestamp.fromDate(startTime),
      "updatedAt": updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,

      "technicianId": technicianId,

      "status": status.wire,
      "notificationType": notificationType.name,
      "priority": priority.name,

      "isNotificationRead": isNotificationRead,

      "startTravel": startTravel != null
          ? Timestamp.fromDate(startTravel!)
          : null,

      "arrivedAt": arrivedAt != null ? Timestamp.fromDate(arrivedAt!) : null,

      "startedWorkingAt": startedWorkingAt != null
          ? Timestamp.fromDate(startedWorkingAt!)
          : null,

      "finishedAt": finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,

      "imagePath": imagePath,
    };
  }
  // ==============================
  // CopyWith
  // ==============================

  Job copyWith({
    JobStatus? status,
    JobNotificationType? notificationType,
    JobPriority? priority,
    bool? isNotificationRead,
    DateTime? startTravel,
    DateTime? arrivedAt,
    DateTime? updatedAt,
    DateTime? startedWorkingAt,
    DateTime? finishedAt,
    DateTime? endTime,
    String? imagePath,
    String? location,
    String? serviceType,
    String? note,
  }) {
    return Job(
      id: id,
      date: date,
      month: month,
      start: start,
      end: end,
      service: service,
      customer: customer,
      phone: phone,
      place: place,
      location: location ?? this.location,
      serviceType: serviceType ?? this.serviceType,
      note: note ?? this.note,
      mapUrl: mapUrl,
      customerNote: customerNote,
      createdAt: createdAt,
      startTime: startTime,
      updatedAt: updatedAt ?? this.updatedAt,
      technicianId: technicianId,
      status: status ?? this.status,
      notificationType: notificationType ?? this.notificationType,
      priority: priority ?? this.priority,
      isNotificationRead: isNotificationRead ?? this.isNotificationRead,
      startTravel: startTravel ?? this.startTravel,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      startedWorkingAt: startedWorkingAt ?? this.startedWorkingAt,
      finishedAt: finishedAt ?? this.finishedAt,
      endTime: endTime ?? this.endTime,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
