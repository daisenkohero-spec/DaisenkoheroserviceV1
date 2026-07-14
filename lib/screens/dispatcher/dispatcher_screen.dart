import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'assign_job_screen.dart';
import 'reporting_screen.dart';

/// Admin dispatcher home — today's job board across the whole team.
class DispatcherScreen extends StatelessWidget {
  const DispatcherScreen({super.key});

  static const primary = Color(0xFF1E3A8A);
  static const bg = Color(0xFFF1F5F9);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dispatcher · Daisenko",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text("ผู้ดูแล: ${auth.user?.name ?? ''}",
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "รายงานสรุป",
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportingScreen()),
            ),
          ),
          IconButton(
            tooltip: "ออกจากระบบ",
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("มอบหมายงาน"),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AssignJobScreen()),
        ),
      ),
      // Technicians first (for the id -> name map), then today's jobs.
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('technicians').snapshots(),
        builder: (context, techSnap) {
          final techNames = <String, String>{};
          if (techSnap.hasData) {
            for (final d in techSnap.data!.docs) {
              final data = d.data() as Map<String, dynamic>;
              techNames[d.id] = (data['name'] ?? '') as String;
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('jobs')
                .where('startTime',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
                .orderBy('startTime')
                .snapshots(),
            builder: (context, jobSnap) {
              if (jobSnap.hasError) {
                return _message("โหลดงานไม่สำเร็จ: ${jobSnap.error}");
              }
              if (!jobSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = jobSnap.data!.docs;
              if (docs.isEmpty) {
                return _message("ยังไม่มีงานวันนี้\nกด \"มอบหมายงาน\" เพื่อสร้างงานแรก");
              }

              final total = docs.length;
              final done = docs
                  .where((d) => (d['status'] ?? '') == 'completed')
                  .length;

              return Column(
                children: [
                  _summaryBar(total, done),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final techName =
                            techNames[data['technicianId']] ?? 'ไม่ระบุช่าง';
                        return _jobCard(data, techName);
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _summaryBar(int total, int done) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.today, size: 18, color: primary),
          const SizedBox(width: 8),
          Text("งานวันนี้ $total รายการ",
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text("เสร็จ $done/$total",
              style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> j, String techName) {
    final status = (j['status'] ?? 'assigned').toString();
    final color = _statusColor(status);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(j['service'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel(status),
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text("${j['customer'] ?? ''}   ·   ${j['start'] ?? ''}-${j['end'] ?? ''}",
              style: const TextStyle(color: Colors.black54)),
          if ((j['place'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(j['place'],
                  style: const TextStyle(color: Colors.black45, fontSize: 13)),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.engineering, size: 16, color: primary),
              const SizedBox(width: 4),
              Text(techName,
                  style: const TextStyle(
                      color: primary, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, height: 1.5)),
        ),
      );

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':
        return Colors.grey;
      case 'working':
        return Colors.blue;
      case 'traveling':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.green; // assigned / accepted
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'completed':
        return 'เสร็จสิ้น';
      case 'working':
        return 'กำลังทำงาน';
      case 'traveling':
        return 'กำลังเดินทาง';
      case 'overdue':
        return 'เลยกำหนด';
      case 'accepted':
        return 'รับงานแล้ว';
      default:
        return 'มอบหมายแล้ว';
    }
  }
}
