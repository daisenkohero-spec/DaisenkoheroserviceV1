import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../service_area_screen.dart' show CertificateCard;

/// แอดมินจัดการช่าง: ใบรับรอง Daisenko, ประเภทช่าง, เปิด/ปิดบัญชี
///
/// ช่างใหม่เข้ามาทางใบสมัคร (Google) หรือ scripts/add-technician.js (เบอร์ + รหัสผ่าน)
class TechniciansScreen extends StatelessWidget {
  const TechniciansScreen({super.key});

  static const primary = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text("จัดการช่าง"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('technicians')
            .orderBy('name')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text("โหลดไม่สำเร็จ: ${snap.error}"));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                "ช่างใหม่สมัครผ่านปุ่ม \"สมัครเป็นช่างด้วย Google\" แล้วอนุมัติที่ไอคอนใบสมัคร",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (final d in docs) ...[
                _TechnicianTile(doc: d),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TechnicianTile extends StatelessWidget {
  const _TechnicianTile({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final active = d['active'] != false;
    final level = (d['cert']?['level'] as num?)?.toInt() ?? 0;
    final hasBase = d['base'] != null;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: active ? const Color(0xFFE0E7FF) : Colors.grey[300],
          child: Text(
            level == 0 ? "–" : "L$level",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: active ? TechniciansScreen.primary : Colors.grey,
            ),
          ),
        ),
        title: Text(
          d['name']?.toString() ?? '-',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: active ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          [
            d['phone'] ?? '-',
            d['employmentType'] == 'external' ? "พาร์ทเนอร์" : "ประจำร้าน",
            hasBase ? "รัศมี ${d['radiusKm'] ?? '-'} กม." : "ยังไม่ตั้งจุดฐาน",
            if (!active) "ปิดบัญชี",
          ].join(" · "),
        ),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => _EditTechnicianSheet(doc: doc),
        ),
      ),
    );
  }
}

class _EditTechnicianSheet extends StatefulWidget {
  const _EditTechnicianSheet({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  State<_EditTechnicianSheet> createState() => _EditTechnicianSheetState();
}

class _EditTechnicianSheetState extends State<_EditTechnicianSheet> {
  late final Map<String, dynamic> _d = widget.doc.data();
  late int _level = (_d['cert']?['level'] as num?)?.toInt() ?? 0;
  late DateTime _certifiedAt = _d['cert']?['certifiedAt'] is Timestamp
      ? (_d['cert']['certifiedAt'] as Timestamp).toDate()
      : DateTime.now();
  late String _type = _d['employmentType'] == 'external' ? 'external' : 'inhouse';
  late bool _active = _d['active'] != false;
  bool _saving = false;

  static const _levels = {
    0: "ยังไม่ผ่านอบรม",
    1: "Level 1 (ล้าง)",
    2: "Level 2 (ล้าง + ซ่อม)",
    3: "Level 3 (ติดตั้ง + VRF)",
  };

  DateTime get _expiresAt =>
      DateTime(_certifiedAt.year + 1, _certifiedAt.month, _certifiedAt.day);

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.doc.reference.update({
        'employmentType': _type,
        'active': _active,
        'cert': _level == 0
            ? FieldValue.delete()
            : {
                'level': _level,
                'certifiedAt': Timestamp.fromDate(_certifiedAt),
                'expiresAt': Timestamp.fromDate(_expiresAt),
                'recordedBy': FirebaseAuth.instance.currentUser?.uid,
              },
      });
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text("บันทึกแล้ว")));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("บันทึกไม่สำเร็จ: $e")));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _level == 0
        ? null
        : {
            'level': _level,
            'expiresAt': Timestamp.fromDate(_expiresAt),
          };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _d['name']?.toString() ?? '-',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text("${_d['phone'] ?? '-'}", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            CertificateCard(cert: preview),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _level,
              decoration: const InputDecoration(labelText: "ระดับใบรับรอง Daisenko"),
              items: _levels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _level = v ?? 0),
            ),
            if (_level > 0)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("วันที่ผ่านอบรม"),
                subtitle: Text(
                  "${_certifiedAt.day}/${_certifiedAt.month}/${_certifiedAt.year}"
                  " · หมดอายุ ${_expiresAt.day}/${_expiresAt.month}/${_expiresAt.year}",
                ),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _certifiedAt,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _certifiedAt = picked);
                },
              ),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: "ประเภทช่าง"),
              items: const [
                DropdownMenuItem(value: 'inhouse', child: Text("ช่างประจำร้าน")),
                DropdownMenuItem(value: 'external', child: Text("ช่างพาร์ทเนอร์ (ภายนอก)")),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'inhouse'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("เปิดใช้งานบัญชี"),
              subtitle: const Text("ปิดแล้ว ช่างเข้าแอปและเห็นงานไม่ได้"),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TechniciansScreen.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? "กำลังบันทึก..." : "บันทึก"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
