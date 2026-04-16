import 'package:cloud_firestore/cloud_firestore.dart';

enum JobStatus {
  pending,
  assigned, // ได้รับงานแล้ว (ยังไม่เริ่ม)
  accepted, // ช่างกดยอมรับงาน
  traveling, // กำลังไปหน้างาน
  working, // กำลังทำงาน
  completed, // เสร็จแล้ว
  cancelled,
  overdue, // เลยกำหนดเวลา
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
    this.status = JobStatus.pending,
    this.notificationType = JobNotificationType.none,
    this.priority = JobPriority.normal,
    this.isNotificationRead = false,
    this.startTravel,
    this.arrivedAt,
    this.startedWorkingAt,
    this.finishedAt,
    this.imagePath,
  });
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

      status: JobStatus.values.firstWhere(
        (e) =>
            e.name.toLowerCase() ==
            (json['status'] ?? '').toString().toLowerCase(),
        orElse: () => JobStatus.pending,
      ),

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
      'status': status.name,
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

      "status": status.name,
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
