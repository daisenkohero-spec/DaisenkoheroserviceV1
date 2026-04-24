import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import '../providers/attendance_provider.dart';
import '../models/job_model.dart';
import 'checkin_screen.dart';
import 'notification_screen.dart';
import '../screens/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoaded = false;

  static const primaryColor = Color(0xFF1E3A8A);
  static const accentColor = Color(0xFF0EA5E9);
  static const bgColor = Color(0xFFF1F5F9);

  String selectedTab = "upcoming";

  // ---------------------------
  // PRIORITY COLOR
  // ---------------------------
  Color priorityColor(JobPriority priority) {
    switch (priority) {
      case JobPriority.urgent:
        return Colors.red;
      case JobPriority.high:
        return Colors.orange;
      case JobPriority.normal:
        return accentColor;
      case JobPriority.low:
        return Colors.grey;
    }
  }

  // ---------------------------
  // INIT
  // ---------------------------
  @override
  void initState() {
    super.initState();
  }

  //  โหลด jobs หลังได้ user
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isLoaded) {
      final user = context.read<AuthProvider>().user;

      if (user != null) {
        context.read<JobProvider>().loadJobs(user.id);
        _isLoaded = true;
      }
    }
  }

  // ---------------------------
  // STATUS ICON
  // ---------------------------
  IconData statusIcon(WeekStatus status) {
    switch (status) {
      case WeekStatus.present:
        return Icons.check_circle;
      case WeekStatus.late:
        return Icons.access_time;
      case WeekStatus.leave:
        return Icons.event_busy;
      case WeekStatus.absent:
        return Icons.cancel;
      case WeekStatus.upcoming:
      default:
        return Icons.schedule;
    }
  }

  // ---------------------------
  // BUILD
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();

    final weekData = attendanceProvider.getThisWeek();
    final todayRecord = attendanceProvider.getTodayRecord();

    final user = context.watch<AuthProvider>().user;

    final unreadCount = jobProvider.unreadNotificationCount;

    int attendancePercent() {
      return attendanceProvider.getMonthlyAttendancePercent();
    }

    String _buildStatusText(BuildContext context, AttendanceRecord record) {
      switch (record.status) {
        case WeekStatus.present:
          return "เข้างาน ${record.checkinTime.format(context)}";
        case WeekStatus.late:
          return "มาสาย ${record.checkinTime.format(context)}";
        case WeekStatus.leave:
          return "ลางาน";
        case WeekStatus.absent:
          return "ขาดงาน";
        case WeekStatus.upcoming:
        default:
          return "ยังไม่ได้เช็กอิน";
      }
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [accentColor, primaryColor]),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  /// LOGO + NOTI + USER
                  Row(
                    children: [
                      Image.asset('assets/images/logo.png', height: 26),

                      const Spacer(),

                      /// Notification
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationScreen(),
                                ),
                              );
                            },
                          ),

                          if (unreadCount > 0)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(width: 12),

                      /// USER NAME (Clickable Logout)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) {
                                return Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 28,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 70,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(
                                              0.1,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.logout_rounded,
                                            color: primaryColor,
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          "ออกจากระบบ",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          "คุณต้องการออกจากระบบใช่หรือไม่?",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 45,
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  style: OutlinedButton.styleFrom(
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text("ยกเลิก"),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: SizedBox(
                                                height: 45,
                                                child: ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        primaryColor,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    "ยืนยัน",
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );

                            if (confirm == true) {
                              await context.read<AuthProvider>().logout();

                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  user?.name ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  /// CHECK-IN CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: accentColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Check attendance วันนี้",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (todayRecord != null)
                                Row(
                                  children: [
                                    Icon(
                                      statusIcon(todayRecord.status),
                                      size: 16,
                                      color: attendanceProvider.getStatusColor(
                                        todayRecord.status,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _buildStatusText(context, todayRecord),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: attendanceProvider
                                            .getStatusColor(todayRecord.status),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: todayRecord != null
                              ? null
                              : () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CheckinScreen(),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                          ),
                          child: const Text(
                            "Check‑in",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "This week status",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: weekData.map<Widget>((e) {
                      return Expanded(
                        child: WeekStatusItem(
                          day: e.day,
                          date: e.date,
                          status: e.status,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _miniCard(
                      Icons.check_circle,
                      "${attendancePercent()}%",
                      "Attendance",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _miniCard(
                      Icons.assignment,
                      jobProvider.allActiveJobs.length.toString(),
                      "Assigned Jobs",
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _nextJobCard(jobProvider),

            const SizedBox(height: 16),

            _requestScheduleCard(jobProvider),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _miniCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FAFF), Color(0xFFEFF6FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _nextJobCard(JobProvider jobProvider) {
    final upcomingJobs = jobProvider.todayUpcomingJobs;
    if (upcomingJobs.isEmpty) {
      return const SizedBox();
    }

    final sortedJobs = [...upcomingJobs]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final nextJob = sortedJobs.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [accentColor, primaryColor]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(.25),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// HEADER ROW
            Row(
              children: [
                const Icon(Icons.upcoming, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  "Next Job",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),

                /// PRIORITY BADGE
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor(nextJob.priority),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    nextJob.priority.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            /// SERVICE
            Text(
              nextJob.service,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            /// CUSTOMER
            Text(
              nextJob.customer,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),

            const SizedBox(height: 12),

            /// TIME ROW
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(
                  "${nextJob.start} - ${nextJob.end}",
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _requestScheduleCard(JobProvider jobProvider) {
    final todayJobs = jobProvider.todayJobs;
    final upcomingJobs = jobProvider.todayUpcomingJobs;
    final ongoingJobs = jobProvider.todayOngoingJobs;
    final overdueJobs = jobProvider.todayOverdueJobs;
    List<Job> displayJobs = [];

    if (selectedTab == "upcoming") {
      displayJobs = upcomingJobs;
    } else if (selectedTab == "ongoing") {
      displayJobs = ongoingJobs;
    } else {
      displayJobs = overdueJobs;
    }
    final completedToday = todayJobs
        .where((j) => j.status == JobStatus.completed)
        .length;

    final progress = todayJobs.isEmpty
        ? 0.0
        : completedToday / todayJobs.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 192, 20, 20).withOpacity(.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "Today's Jobs",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: primaryColor,
                  ),
                ),

                const Spacer(),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${todayJobs.length} Requests",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(10),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(accentColor),
            ),
            const SizedBox(height: 8),
            Text(
              "$completedToday / ${todayJobs.length} jobs completed",
              style: const TextStyle(fontSize: 12),
            ),

            Text(
              "${(progress * 100).toInt()}% Completed",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 16),

            if (todayJobs.isEmpty)
              Column(
                children: [
                  Icon(Icons.event_available, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    "No jobs today",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Enjoy your free day ",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _statusBox(
                    icon: Icons.schedule,
                    label: "Upcoming",
                    count: upcomingJobs.length,
                    color: accentColor,
                    isSelected: selectedTab == "upcoming",
                    onTap: () {
                      setState(() {
                        selectedTab = "upcoming";
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statusBox(
                    icon: Icons.build_circle,
                    label: "Ongoing",
                    count: ongoingJobs.length,
                    color: primaryColor,
                    isSelected: selectedTab == "ongoing",
                    onTap: () {
                      setState(() {
                        selectedTab = "ongoing";
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statusBox(
                    icon: Icons.warning_amber,
                    label: "Overdue",
                    count: overdueJobs.length,
                    color: Colors.red,
                    isSelected: selectedTab == "overdue",
                    onTap: () {
                      setState(() {
                        selectedTab = "overdue";
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ...displayJobs.map((job) {
              final borderColor = jobProvider.getJobBorderColor(job);
              final bgColor = jobProvider.getJobBgColor(job);

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ///  HEADER ROW
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            job.service,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),

                        /// PRIORITY
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor(job.priority).withOpacity(.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            job.priority.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: priorityColor(job.priority),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    ///  CUSTOMER
                    Text(
                      job.customer,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),

                    const SizedBox(height: 6),

                    ///  PLACE
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            job.place,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    ///  TIME
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${job.start} - ${job.end}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

Widget _jobItem(Job job, {bool isOverdue = false}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isOverdue ? Colors.red.withOpacity(.06) : Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      border: isOverdue ? Border.all(color: Colors.red.withOpacity(.3)) : null,
    ),
    child: Row(
      children: [
        if (isOverdue)
          Container(
            width: 4,
            height: 40,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.service,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                job.customer,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                "${job.start} - ${job.end}",
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class WeekStatusItem extends StatelessWidget {
  final String day;
  final int date;
  final WeekStatus status;

  const WeekStatusItem({
    super.key,
    required this.day,
    required this.date,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();
    final now = DateTime.now();
    final isToday = date == now.day;
    final Color primaryColor = const Color(0xFF1E3A8A);

    return Column(
      children: [
        Text(
          day,
          style: TextStyle(
            fontSize: 10,
            color: isToday ? primaryColor : Colors.grey[500],
            fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isToday ? primaryColor.withOpacity(0.08) : Colors.grey[100],
            border: Border.all(
              color: attendance.getStatusColor(status).withOpacity(0.5),
              width: 1.2,
            ),
          ),
          child: Text(
            date.toString(),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isToday ? primaryColor : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 3,
          width: isToday ? 20 : 0,
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }
}

Widget _statusBox({
  required IconData icon,
  required String label,
  required int count,
  required Color color,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(.2) : color.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    ),
  );
}
