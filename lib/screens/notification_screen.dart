import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/job_provider.dart';
import '../models/job_model.dart';
import 'task_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      context.read<JobProvider>().loadJobs("tech001");
    });
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();
    print("JOB COUNT: ${jobProvider.jobs.length}");

    final grouped = jobProvider.getGroupedNotifications();

    final today = grouped["today"]!;
    final thisWeek = grouped["thisWeek"]!;
    final others = grouped["overdue"]!;
    final allNoti = [...today, ...thisWeek, ...others];
    return Scaffold(
      body: Stack(
        children: [
          /// Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E40AF), Color(0xFF1E3A8A)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Notifications",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: allNoti.isEmpty
                        ? const Center(
                            child: Text(
                              "No notifications",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView(
                            children: [
                              if (today.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Today",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      "${today.length} jobs",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 1,
                                  color: Colors.grey.withOpacity(0.15),
                                ),
                                const SizedBox(height: 16),

                                const SizedBox(height: 16),
                                ...today.map(
                                  (job) => _notificationCard(
                                    context,
                                    job,
                                    jobProvider,
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                              if (others.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Overdue",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      "${others.length} jobs",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 1,
                                  color: Colors.grey.withOpacity(0.15),
                                ),
                                const SizedBox(height: 16),

                                const SizedBox(height: 16),

                                ...others.map(
                                  (job) => _notificationCard(
                                    context,
                                    job,
                                    jobProvider,
                                  ),
                                ),
                              ],
                              if (thisWeek.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "This Week",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      "${thisWeek.length} jobs",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 1,
                                  color: Colors.grey.withOpacity(0.15),
                                ),
                                const SizedBox(height: 16),
                                const SizedBox(height: 16),
                                ...thisWeek.map(
                                  (job) => _notificationCard(
                                    context,
                                    job,
                                    jobProvider,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ================= CARD =================

  Widget _notificationCard(
    BuildContext context,
    Job job,
    JobProvider jobProvider,
  ) {
    final isUnread = !job.isNotificationRead;
    final isOverdue = job.isOverdue;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          jobProvider.markNotificationAsRead(job.id);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskScreen()),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: job.status == JobStatus.completed
                ? Colors.grey.shade100
                : Colors.white,
            borderRadius: BorderRadius.circular(18),

            border: Border.all(
              color: isOverdue
                  ? Colors.red.withOpacity(0.3)
                  : isUnread
                  ? const Color(0xFF3B82F6).withOpacity(0.15)
                  : Colors.grey.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A8A),
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(width: 8),

              const SizedBox(width: 8),

              _buildIcon(
                job.notificationType ?? JobNotificationType.newJob,
                job,
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ///  TITLE + STATUS
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _getTitle(job),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: job.status == JobStatus.completed
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                        ),

                        if (job.status == JobStatus.completed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "Completed",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    /// LATE
                    if (isOverdue)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          "Late",
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 8),

                    /// DATE + TIME
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Baseline(
                          baseline: 14,
                          baselineType: TextBaseline.alphabetic,
                          child: Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Baseline(
                          baseline: 14,
                          baselineType: TextBaseline.alphabetic,
                          child: Text(
                            "${job.date} ${job.month}",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Baseline(
                          baseline: 14,
                          baselineType: TextBaseline.alphabetic,
                          child: Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Baseline(
                          baseline: 14,
                          baselineType: TextBaseline.alphabetic,
                          child: Text(
                            "${job.start} - ${job.end}",
                            style: const TextStyle(fontSize: 12),
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
    );
  }

  Widget _buildIcon(JobNotificationType type, Job job) {
    IconData icon;
    Color color;

    ///  ใช้ status ตัดก่อน
    if (job.status == JobStatus.completed) {
      icon = Icons.task_alt;
      color = Colors.green;
    } else {
      switch (type) {
        case JobNotificationType.newJob:
          icon = Icons.work_outline;
          color = const Color(0xFF3B82F6);
          break;

        case JobNotificationType.rescheduled:
          icon = Icons.schedule_outlined;
          color = const Color(0xFFF59E0B);
          break;

        case JobNotificationType.cancelled:
          icon = Icons.close_rounded;
          color = const Color(0xFFEF4444);
          break;

        default:
          icon = Icons.notifications_none;
          color = Colors.grey;
      }
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withOpacity(0.12),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _getTitle(Job job) {
    if (job.status == JobStatus.completed) {
      return "เสร็จแล้ว: ${job.service}";
    }

    if (job.status == JobStatus.working) {
      return "กำลังทำงาน: ${job.service}";
    }

    if (job.status == JobStatus.traveling) {
      return "กำลังเดินทาง: ${job.service}";
    }

    switch (job.notificationType) {
      case JobNotificationType.newJob:
        return "งานใหม่: ${job.service}";

      case JobNotificationType.rescheduled:
        return "งานถูกเลื่อนเวลา";

      case JobNotificationType.cancelled:
        return "งานถูกยกเลิก";

      default:
        return job.service;
    }
  }
}

extension JobX on Job {
  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  bool get isOverdue {
    return startTime.isBefore(DateTime.now()) && !isToday;
  }
}
