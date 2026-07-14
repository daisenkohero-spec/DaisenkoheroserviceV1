import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin reporting dashboard — attendance, jobs completed, and average
/// on-site time per technician, over a selectable date range. Reads the
/// append-only `activity_events` log.
class ReportingScreen extends StatefulWidget {
  const ReportingScreen({super.key});

  @override
  State<ReportingScreen> createState() => _ReportingScreenState();
}

enum _Range { today, week, month }

class _TechStats {
  int present = 0;
  int late = 0;
  int leave = 0;
  final Set<String> completedJobIds = {};
  int totalDurationMin = 0;
  int durationCount = 0;

  int get attendanceDays => present + late + leave;
  double? get avgOnSite =>
      durationCount > 0 ? totalDurationMin / durationCount : null;
}

class _ReportingScreenState extends State<ReportingScreen> {
  static const primary = Color(0xFF1E3A8A);
  static const bg = Color(0xFFF1F5F9);

  _Range _range = _Range.week;

  (DateTime, DateTime) _rangeBounds() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_range) {
      case _Range.today:
        return (today, today.add(const Duration(days: 1)));
      case _Range.week:
        final start = today.subtract(Duration(days: now.weekday - 1)); // Monday
        return (start, start.add(const Duration(days: 7)));
      case _Range.month:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return (start, end);
    }
  }

  Future<(Map<String, String>, Map<String, _TechStats>)> _load() async {
    final db = FirebaseFirestore.instance;
    final (start, end) = _rangeBounds();

    final techSnap = await db.collection('technicians').get();
    final names = <String, String>{};
    for (final d in techSnap.docs) {
      names[d.id] = (d.data()['name'] ?? '') as String;
    }

    final eventSnap = await db
        .collection('activity_events')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('timestamp', isLessThan: Timestamp.fromDate(end))
        .get();

    final stats = <String, _TechStats>{};
    for (final d in eventSnap.docs) {
      final data = d.data();
      final techId = (data['technicianId'] ?? '') as String;
      if (techId.isEmpty) continue;
      final type = (data['type'] ?? '') as String;
      final meta = (data['meta'] ?? const {}) as Map<String, dynamic>;
      final s = stats.putIfAbsent(techId, () => _TechStats());

      if (type == 'attendance_checkin') {
        switch (meta['status']) {
          case 'present':
            s.present++;
            break;
          case 'late':
            s.late++;
            break;
          case 'leave':
            s.leave++;
            break;
        }
      } else if (type == 'job_finish') {
        final jobId = data['jobId'] as String?;
        if (jobId != null && s.completedJobIds.add(jobId)) {
          final dur = meta['durationMin'];
          if (dur is num) {
            s.totalDurationMin += dur.toInt();
            s.durationCount++;
          }
        }
      }
    }
    return (names, stats);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text("รายงานสรุป"),
      ),
      body: Column(
        children: [
          _rangeSelector(),
          Expanded(
            child: FutureBuilder<(Map<String, String>, Map<String, _TechStats>)>(
              future: _load(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _msg("โหลดรายงานไม่สำเร็จ:\n${snap.error}");
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final (names, stats) = snap.data!;
                if (names.isEmpty) {
                  return _msg("ยังไม่มีช่างในระบบ");
                }

                // Overall totals
                var totalJobs = 0;
                var totalDur = 0;
                var durCount = 0;
                for (final s in stats.values) {
                  totalJobs += s.completedJobIds.length;
                  totalDur += s.totalDurationMin;
                  durCount += s.durationCount;
                }
                final overallAvg =
                    durCount > 0 ? (totalDur / durCount).round() : null;

                final techIds = names.keys.toList()
                  ..sort((a, b) => (names[a] ?? '').compareTo(names[b] ?? ''));

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  children: [
                    _summaryRow(names.length, totalJobs, overallAvg),
                    const SizedBox(height: 12),
                    for (final id in techIds)
                      _techCard(names[id] ?? '(ไม่มีชื่อ)',
                          stats[id] ?? _TechStats()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeSelector() {
    Widget chip(String label, _Range r) {
      final sel = _range == r;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _range = r),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Text(label,
                style: TextStyle(
                    color: sel ? Colors.white : primary,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Row(
        children: [
          chip("วันนี้", _Range.today),
          chip("สัปดาห์นี้", _Range.week),
          chip("เดือนนี้", _Range.month),
        ],
      ),
    );
  }

  Widget _summaryRow(int techs, int jobs, int? avg) {
    Widget tile(String value, String label, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(icon, color: primary),
                const SizedBox(height: 6),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        tile("$techs", "ช่างทั้งหมด", Icons.groups),
        const SizedBox(width: 8),
        tile("$jobs", "งานเสร็จ", Icons.check_circle),
        const SizedBox(width: 8),
        tile(avg == null ? "-" : "$avg", "นาที/งาน (เฉลี่ย)", Icons.timer),
      ],
    );
  }

  Widget _techCard(String name, _TechStats s) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.engineering, size: 18, color: primary),
              const SizedBox(width: 6),
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const Divider(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _stat("เข้างาน", "${s.present}", Colors.green),
              _stat("สาย", "${s.late}", Colors.orange),
              _stat("ลา", "${s.leave}", Colors.blueGrey),
              _stat("งานเสร็จ", "${s.completedJobIds.length}", primary),
              _stat("เวลาเฉลี่ย",
                  s.avgOnSite == null ? "-" : "${s.avgOnSite!.round()} น.",
                  Colors.teal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16, color: color)),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _msg(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, height: 1.5)),
        ),
      );
}
