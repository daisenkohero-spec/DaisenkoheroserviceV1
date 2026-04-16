import 'package:flutter/material.dart';
import '../models/job_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import 'dart:async';

class JobProvider extends ChangeNotifier {
  List<Job> _jobs = [];
  Job? _selectedJob;
  StreamSubscription<QuerySnapshot>? _jobSubscription;
  List<Job> get jobs => _jobs;
  Job? get selectedJob => _selectedJob;
  bool isOverdue(Job job) {
    final now = DateTime.now();

    return job.status != JobStatus.completed && job.endTime.isBefore(now);
  }

  double get todayProgress {
    final now = DateTime.now();

    final todayJobs = _jobs.where((job) {
      return job.startTime.year == now.year &&
          job.startTime.month == now.month &&
          job.startTime.day == now.day;
    }).toList();

    if (todayJobs.isEmpty) return 0.0;

    final completed = todayJobs
        .where((j) => j.status == JobStatus.completed)
        .length;

    return completed / todayJobs.length;
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    super.dispose();
  }

  /// ===============================
  /// Load jobs
  /// ===============================
  void loadJobs(String technicianId) {
    _jobSubscription?.cancel();

    _jobSubscription = FirebaseFirestore.instance
        .collection("jobs")
        .where("technicianId", isEqualTo: technicianId)
        .snapshots()
        .listen((snapshot) {
          final newJobs = snapshot.docs.map<Job>((doc) {
            final data = doc.data() as Map<String, dynamic>;

            return Job.fromFirestore(data, doc.id);
          }).toList();

          // notification
          for (var job in newJobs) {
            final oldJob = _jobs.where((j) => j.id == job.id).isNotEmpty
                ? _jobs.firstWhere((j) => j.id == job.id)
                : null;

            final isNew = oldJob == null;

            final statusChanged = oldJob != null && oldJob.status != job.status;

            if ((isNew || statusChanged) &&
                job.isNotificationRead == false &&
                job.notificationType == JobNotificationType.newJob) {
              NotificationService.showNotification("งานใหม่", job.service);
            }
          }

          _jobs = newJobs;
          notifyListeners();
        });
  }

  /// ===============================
  /// Select job
  /// ===============================
  void selectJob(String jobId) {
    if (_selectedJob?.id == jobId) {
      //  กดซ้ำ = ปิด
      _selectedJob = null;
    } else {
      try {
        _selectedJob = _jobs.firstWhere((job) => job.id == jobId);
      } catch (_) {
        _selectedJob = null;
      }
    }
    notifyListeners();
  }

  /// all active jobs

  List<Job> get allActiveJobs {
    return _jobs.where((job) {
      return job.status != JobStatus.completed;
    }).toList();
  }

  /// ===============================
  /// Today jobs
  /// ===============================
  List<Job> get todayJobs {
    final now = DateTime.now();

    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _jobs.where((job) {
      return job.startTime.isBefore(endOfDay) &&
          job.endTime.isAfter(startOfDay);
    }).toList();
  }

  Map<String, List<Job>> getGroupedNotifications() {
    final now = DateTime.now();

    final notifyJobs = jobs
        .where((job) => job.notificationType != JobNotificationType.none)
        .toList();

    final today = <Job>[];
    final thisWeek = <Job>[];
    final overdue = <Job>[];

    for (var job in notifyJobs) {
      final isToday =
          job.startTime.year == now.year &&
          job.startTime.month == now.month &&
          job.startTime.day == now.day;

      if (isToday) {
        today.add(job);
        continue;
      }

      final diff = job.startTime.difference(now).inDays;

      if (job.startTime.isBefore(now)) {
        overdue.add(job);
      } else if (diff <= 7) {
        thisWeek.add(job);
      }
    }
    today.sort((a, b) => a.startTime.compareTo(b.startTime));

    thisWeek.sort((a, b) => a.startTime.compareTo(b.startTime));

    overdue.sort((a, b) => b.startTime.compareTo(a.startTime));
    return {"today": today, "thisWeek": thisWeek, "overdue": overdue};
  }

  /// ===============================
  /// Sorted jobs
  /// ===============================
  List<Job> getSortedJobsForTechnician(String technicianId) {
    final list = _jobs
        .where((job) => job.technicianId == technicianId)
        .toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return list;
  }

  List<Job> get todayUpcomingJobs {
    final now = DateTime.now();
    return todayJobs.where((job) {
      return job.startTime.isAfter(now) && job.status != JobStatus.completed;
    }).toList();
  }

  List<Job> get todayOngoingJobs {
    final now = DateTime.now();
    return todayJobs.where((job) {
      return job.startTime.isBefore(now) && job.endTime.isAfter(now);
    }).toList();
  }

  List<Job> get todayOverdueJobs {
    final now = DateTime.now();
    return todayJobs.where((job) {
      return job.endTime.isBefore(now) && job.status != JobStatus.completed;
    }).toList();
  }

  List<Job> get nearingDueJobs {
    final now = DateTime.now();
    return jobs.where((job) {
      final diff = job.endTime.difference(now).inMinutes;
      return diff > 0 && diff <= 30; // ก่อนหมดเวลา 30 นาที
    }).toList();
  }

  /// ===============================
  /// Notification count
  /// ===============================
  int get unreadNotificationCount {
    return _jobs.where((job) {
      return job.isNotificationRead == false &&
          job.notificationType != JobNotificationType.none;
    }).length;
  }

  /// ===============================
  /// Active jobs
  /// ===============================
  List<Job> get activeJobs {
    return _jobs.where((job) {
      return job.status == JobStatus.traveling ||
          job.status == JobStatus.working;
    }).toList();
  }

  /// ===============================
  /// Upcoming jobs
  /// ===============================
  List<Job> get upcomingJobs {
    return _jobs.where((job) {
      return job.status == JobStatus.pending ||
          job.status == JobStatus.assigned;
    }).toList();
  }

  bool isUpcoming(Job job) {
    final now = DateTime.now();

    return (job.status == JobStatus.pending ||
            job.status == JobStatus.assigned) &&
        job.startTime.isAfter(now);
  }

  /// ===============================
  /// Selected job ID
  /// ===============================
  String? get selectedJobId => _selectedJob?.id;

  /// ===============================
  /// Overdue jobs
  /// ===============================
  List<Job> get overdueJobs {
    final now = DateTime.now();

    return _jobs.where((job) {
      return job.status != JobStatus.completed && job.endTime.isBefore(now);
    }).toList();
  }

  /// ===============================
  /// Start working
  /// ===============================
  ///  NOTE: direct mutation for simplicity
  Future<void> startWorking(String jobId) async {
    try {
      final job = _jobs.firstWhere((j) => j.id == jobId);

      job.status = JobStatus.working;
      job.isNotificationRead = true;
      job.startedWorkingAt = DateTime.now();

      notifyListeners();

      await FirebaseFirestore.instance.collection("jobs").doc(jobId).update({
        "status": "working",
        "isNotificationRead": true,
        "startedWorkingAt": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("startWorking error: $e");
      rethrow;
    }
  }

  /// ===============================
  /// Complete job
  /// ===============================
  Future<void> completeJob(String jobId) async {
    try {
      final job = _jobs.firstWhere((j) => j.id == jobId);

      job.status = JobStatus.completed;
      job.finishedAt = DateTime.now();

      job.notificationType = JobNotificationType.jobUpdate;
      job.isNotificationRead = false;

      notifyListeners();

      await FirebaseFirestore.instance.collection("jobs").doc(jobId).update({
        "status": "completed",
        "finishedAt": FieldValue.serverTimestamp(),

        "notificationType": "jobUpdate",
        "isNotificationRead": false,
      });
    } catch (e) {
      print("completeJob error: $e");
    }
  }

  /// ===============================
  /// Update job
  /// ===============================
  Future<void> updateJob(Job updatedJob) async {
    try {
      await FirebaseFirestore.instance
          .collection("jobs")
          .doc(updatedJob.id)
          .update(updatedJob.toMap());
    } catch (e) {
      print("updateJob error: $e");
    }
  }

  /// ===============================
  /// Mark notification read
  /// ===============================
  Future<void> markNotificationAsRead(String jobId) async {
    try {
      final job = _jobs.firstWhere((j) => j.id == jobId);

      job.isNotificationRead = true;

      notifyListeners();

      await FirebaseFirestore.instance.collection("jobs").doc(jobId).update({
        "isNotificationRead": true,
      });
    } catch (e) {
      print("notification error: $e");
    }
  }

  String getJobCategory(Job job) {
    final now = DateTime.now();

    if (job.status == JobStatus.completed) {
      return "completed";
    }

    if (job.endTime.isBefore(now)) {
      return "overdue";
    } else if (job.startTime.isBefore(now) && job.endTime.isAfter(now)) {
      return "ongoing";
    } else {
      return "upcoming";
    }
  }

  Color getJobBorderColor(Job job) {
    final now = DateTime.now();

    if (job.status == JobStatus.completed) {
      return Colors.grey;
    }

    if (job.endTime.isBefore(now)) {
      return Colors.red;
    }

    if (job.startTime.isBefore(now) && job.endTime.isAfter(now)) {
      return Colors.blue;
    }

    return Colors.green;
  }

  Color getJobBgColor(Job job) {
    final border = getJobBorderColor(job);
    return border.withOpacity(0.06);
  }
}
