import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_model.dart';
import '../providers/job_provider.dart';
import 'map_screen.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  static const primaryColor = Color(0xFF1E3A8A);
  static const accentColor = Color(0xFF0EA5E9);
  static const bgColor = Color(0xFFF1F5F9);

  bool inProgressOpen = true;
  bool overdueOpen = true;
  bool upcomingOpen = true;
  bool finishedOpen = false;

  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();
    final jobs = jobProvider.jobs;
    final now = DateTime.now();

    final inProgressJobs = jobs
        .where((j) => j.status == JobStatus.working)
        .toList();

    final overdueJobs = jobProvider.overdueJobs;

    final upcomingJobs = jobs.where((j) {
      return j.status != JobStatus.completed &&
          j.status != JobStatus.working &&
          j.startTime.isAfter(now);
    }).toList();

    final finishedJobs = jobs
        .where((j) => j.status == JobStatus.completed)
        .toList();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(90),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const Spacer(),
              const Text(
                "Task",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
      body: Container(
        color: bgColor,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            /// ===== IN PROGRESS =====
            if (inProgressJobs.isNotEmpty) ...[
              _header(
                'In progress (${inProgressJobs.length})',
                inProgressOpen,
                () => setState(() => inProgressOpen = !inProgressOpen),
                Colors.orange,
              ),
              if (inProgressOpen) ...inProgressJobs.map((job) => _item(job)),
              const SizedBox(height: 24),
            ],

            /// ===== OVERDUE =====
            if (overdueJobs.isNotEmpty) ...[
              _header(
                'Late jobs (${overdueJobs.length})',
                overdueOpen,
                () => setState(() => overdueOpen = !overdueOpen),
                Colors.red,
              ),
              if (overdueOpen) ...overdueJobs.map((job) => _item(job)),
              const SizedBox(height: 24),
            ],

            /// ===== UPCOMING =====
            _header(
              'Upcoming (${upcomingJobs.length})',
              upcomingOpen,
              () => setState(() => upcomingOpen = !upcomingOpen),
              primaryColor,
            ),
            if (upcomingOpen) ...upcomingJobs.map((job) => _item(job)),

            const SizedBox(height: 24),

            /// ===== FINISHED =====
            _header(
              'Finished (${finishedJobs.length})',
              finishedOpen,
              () => setState(() => finishedOpen = !finishedOpen),
              Colors.green,
            ),
            if (finishedOpen) ...finishedJobs.map((job) => _item(job)),
          ],
        ),
      ),
    );
  }

  Widget _noteBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 16, color: primaryColor),
          const SizedBox(width: 6),
          Text(
            "มีหมายเหตุจากลูกค้า",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String title, bool open, VoidCallback onTap, Color dotColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const Spacer(),
            Icon(
              open ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }

  Widget _item(Job job) {
    final selectedId = context.watch<JobProvider>().selectedJobId;
    final isSelected = job.id == selectedId;

    final finished = job.status == JobStatus.completed;
    final isOverdue = context.read<JobProvider>().isOverdue(job);

    return GestureDetector(
      onTap: () {
        context.read<JobProvider>().selectJob(job.id);
      },

      child: Stack(
        children: [
          /// การ์ดหลัก
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 16, left: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor.withOpacity(.05) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ///  HEADER BOX (ใหม่)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// service + badge
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

                          if (isOverdue)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "OVERDUE",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      /// เวลา
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${job.start} - ${job.end}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                /// ลูกค้า + เบอร์
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job.customer.isEmpty ? "-" : job.customer,
                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),

                if (job.phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          job.phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 6),

                /// สถานที่
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        job.place,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                if (job.customerNote != null &&
                    job.customerNote!.isNotEmpty) ...[
                  _noteBadge(),
                  const SizedBox(height: 20),
                ],

                if (isSelected &&
                    job.customerNote != null &&
                    job.customerNote!.isNotEmpty) ...[
                  const SizedBox(height: 16),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(.05),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: primaryColor.withOpacity(.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.sticky_note_2,
                          size: 20,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "หมายเหตุจากลูกค้า",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                job.customerNote!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                /// bottom action box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.withOpacity(.08)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: accentColor.withOpacity(.4),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: Icon(Icons.call, size: 18, color: accentColor),
                          label: Text(
                            'Call',
                            style: TextStyle(color: accentColor),
                          ),
                          onPressed: finished ? null : () => _call(job.phone),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            elevation: 2,
                            shadowColor: primaryColor.withOpacity(.25),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.map,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: Text(
                            finished ? 'Done' : 'Open Map',
                            style: const TextStyle(color: Colors.white),
                          ),
                          onPressed: finished
                              ? null
                              : () async {
                                  final provider = context.read<JobProvider>();

                                  provider.startWorking(job.id);
                                  provider.selectJob(job.id);

                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MapScreen(job: job),
                                    ),
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
