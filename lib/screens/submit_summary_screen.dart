import 'dart:io';
import 'package:flutter/material.dart';
import '../models/job_model.dart';
import 'package:provider/provider.dart';
import '../providers/job_provider.dart';
import 'nav_screen.dart';

class SubmitSummaryPage extends StatelessWidget {
  const SubmitSummaryPage({super.key});

  static const primaryColor = Color(0xFF1E3A8A);
  static const accentColor = Color(0xFF0EA5E9);
  static const bgColor = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    final jobs = context.watch<JobProvider>().jobs;

    final completedJobs = jobs
        .where((j) => j.status == JobStatus.completed)
        .toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NavScreen(initialIndex: 0),
                    ),
                    (route) => false,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const Spacer(),
              const Text(
                "สรุปงานที่เสร็จแล้ว",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 40),
            ],
          ),
        ),
      ),
      body: completedJobs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.inbox, size: 60, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    "ยังไม่มีงานที่สำเร็จ",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: completedJobs.length,
              itemBuilder: (context, index) {
                final job = completedJobs[index];
                return _buildCard(job);
              },
            ),
    );
  }

  Widget _buildCard(Job job) {
    final start = job.startedWorkingAt;
    final end = job.finishedAt;

    final dateText = end != null
        ? "${end.day}/${end.month}/${end.year}"
        : "--/--/----";

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
          /// HEADER
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.customer,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.service,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  "สำเร็จ",
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          /// JOB ID
          _infoRow(Icons.confirmation_number, "รหัสงาน", job.id),

          const SizedBox(height: 10),

          /// DATE
          _infoRow(Icons.calendar_today, "วันที่", dateText),

          const SizedBox(height: 10),

          /// TIME RANGE
          _infoRow(
            Icons.schedule,
            "เวลาทำงาน",
            (start != null && end != null)
                ? "${_formatTime(start)} - ${_formatTime(end)}"
                : "--",
          ),

          const SizedBox(height: 10),

          /// DURATION
          _infoRow(
            Icons.timer,
            "ใช้เวลา",
            _calculateDuration(start, end),
            highlight: true,
          ),

          const SizedBox(height: 18),

          /// IMAGE SECTION
          const Text("รูปงาน", style: TextStyle(fontWeight: FontWeight.w600)),

          const SizedBox(height: 10),

          job.imagePath == null
              ? Container(
                  height: 110,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "ไม่มีรูปแนบ",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(job.imagePath!),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String title,
    String value, {
    bool highlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryColor),
        const SizedBox(width: 8),
        Text(title),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: highlight ? primaryColor : Colors.black87,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime d) {
    return "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  String _calculateDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return "--";

    final seconds = end.difference(start).inSeconds;
    final minutes = (seconds / 60).ceil();
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0 && mins > 0) {
      return "$hours ชม. $mins นาที";
    } else if (hours > 0) {
      return "$hours ชม.";
    } else {
      return "$mins นาที";
    }
  }
}
