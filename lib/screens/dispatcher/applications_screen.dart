import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// แอดมินตรวจใบสมัครช่างใหม่ (applications, status = pending)
///
/// อนุมัติ = สร้างเอกสาร technicians ผูกกับบัญชี Google ของผู้สมัคร (authUid)
/// พร้อมบันทึกผลอบรม Daisenko ที่แอดมินตรวจสอบแล้ว
class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({super.key});

  static const primary = Color(0xFF1E3A8A);

  static Stream<QuerySnapshot<Map<String, dynamic>>> pendingStream() =>
      FirebaseFirestore.instance
          .collection('applications')
          .where('status', isEqualTo: 'pending')
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text("ใบสมัครช่างใหม่"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: pendingStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text("โหลดไม่สำเร็จ: ${snap.error}"));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "ไม่มีใบสมัครที่รอตรวจ",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ApplicationCard(doc: docs[i]),
          );
        },
      ),
    );
  }
}

const _levelNames = {
  0: "ยังไม่ผ่านอบรม",
  1: "Level 1 (ล้าง)",
  2: "Level 2 (ล้าง + ซ่อม)",
  3: "Level 3 (ติดตั้ง + VRF)",
};

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final claimed = (d['trainingLevelClaimed'] as num?)?.toInt() ?? 0;
    final submitted = d['submittedAt'] is Timestamp
        ? (d['submittedAt'] as Timestamp).toDate()
        : null;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d['name']?.toString() ?? '-',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text("เบอร์โทร: ${d['phone'] ?? '-'}"),
            Text("Google: ${d['email'] ?? '-'}"),
            Text("พื้นที่: ${d['area'] ?? '-'}"),
            Text("แจ้งผลอบรม: ${_levelNames[claimed] ?? '-'}"),
            if (submitted != null)
              Text(
                "ส่งเมื่อ ${submitted.day}/${submitted.month}/${submitted.year}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(context),
                    child: const Text("ไม่อนุมัติ"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ApplicationsScreen.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _approve(context, claimed),
                    child: const Text("อนุมัติ"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("ไม่อนุมัติใบสมัคร"),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(
            labelText: "เหตุผล (ผู้สมัครจะเห็นข้อความนี้)",
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("ยกเลิก")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("ไม่อนุมัติ")),
        ],
      ),
    );
    if (ok != true) return;
    await doc.reference.update({
      'status': 'rejected',
      'rejectReason': reason.text.trim(),
      'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _approve(BuildContext context, int claimed) async {
    final d = doc.data();
    final db = FirebaseFirestore.instance;
    final messenger = ScaffoldMessenger.of(context);

    // เบอร์ซ้ำกับช่างที่มีอยู่แล้ว: ให้ช่างคนนั้นเชื่อม Google จากบัญชีเดิมแทน
    final dup = await db
        .collection('technicians')
        .where('phone', isEqualTo: d['phone'])
        .limit(1)
        .get();
    if (dup.docs.isNotEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
          "เบอร์นี้มีช่างอยู่แล้ว ให้ช่างเข้าสู่ระบบด้วยเบอร์โทรแล้วเชื่อม Google แทน หรือกด \"ไม่อนุมัติ\" พร้อมแจ้งเหตุผล",
        ),
      ));
      return;
    }
    if (!context.mounted) return;

    final result = await showDialog<_Approval>(
      context: context,
      builder: (_) => _ApproveDialog(initialLevel: claimed),
    );
    if (result == null) return;

    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    final techRef = db.collection('technicians').doc();
    final certifiedAt = result.certifiedAt;
    final expiresAt = DateTime(
      certifiedAt.year + 1,
      certifiedAt.month,
      certifiedAt.day,
    );

    final batch = db.batch();
    batch.set(techRef, {
      'name': d['name'],
      'phone': d['phone'],
      'email': d['email'],
      'area': d['area'],
      'authUid': doc.id, // uid ของบัญชี Google ผู้สมัคร
      'employmentType': result.employmentType,
      'status': 'offline',
      'source': 'signup',
      'createdAt': FieldValue.serverTimestamp(),
      if (result.level > 0)
        'cert': {
          'level': result.level,
          'certifiedAt': Timestamp.fromDate(certifiedAt),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'recordedBy': adminUid,
        },
    });
    batch.update(doc.reference, {
      'status': 'approved',
      'technicianId': techRef.id,
      'reviewedBy': adminUid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    try {
      await batch.commit();
      messenger.showSnackBar(
        SnackBar(content: Text("อนุมัติ ${d['name']} แล้ว")),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("อนุมัติไม่สำเร็จ: $e")));
    }
  }
}

class _Approval {
  _Approval(this.level, this.certifiedAt, this.employmentType);
  final int level;
  final DateTime certifiedAt;
  final String employmentType;
}

class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.initialLevel});
  final int initialLevel;

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  late int _level = widget.initialLevel;
  DateTime _certifiedAt = DateTime.now();
  String _type = 'external';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("อนุมัติเป็นช่าง"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ยืนยันผลอบรมกับ Daisenko ก่อนอนุมัติ",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _level,
            decoration: const InputDecoration(labelText: "ระดับที่รับรอง"),
            items: _levelNames.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _level = v ?? 0),
          ),
          if (_level > 0) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("วันที่ผ่านอบรม"),
              subtitle: Text(
                "${_certifiedAt.day}/${_certifiedAt.month}/${_certifiedAt.year} · หมดอายุใน 1 ปี",
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _certifiedAt,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _certifiedAt = picked);
              },
            ),
          ],
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: "ประเภทช่าง"),
            items: const [
              DropdownMenuItem(value: 'external', child: Text("ช่างพาร์ทเนอร์ (ภายนอก)")),
              DropdownMenuItem(value: 'inhouse', child: Text("ช่างประจำร้าน")),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'external'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("ยกเลิก")),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _Approval(_level, _certifiedAt, _type),
          ),
          child: const Text("อนุมัติ"),
        ),
      ],
    );
  }
}
