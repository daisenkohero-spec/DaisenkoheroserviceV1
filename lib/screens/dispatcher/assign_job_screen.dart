import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin form to create & assign a job to a technician (writes to `jobs`).
class AssignJobScreen extends StatefulWidget {
  const AssignJobScreen({super.key});

  @override
  State<AssignJobScreen> createState() => _AssignJobScreenState();
}

class _AssignJobScreenState extends State<AssignJobScreen> {
  static const primary = Color(0xFF1E3A8A);

  final _formKey = GlobalKey<FormState>();
  final _customer = TextEditingController();
  final _phone = TextEditingController();
  final _service = TextEditingController();
  final _place = TextEditingController();

  String? _technicianId;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 11, minute: 0);
  bool _saving = false;

  static const _months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
  ];

  @override
  void dispose() {
    _customer.dispose();
    _phone.dispose();
    _service.dispose();
    _place.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  Future<void> _pickTime(bool isStart) async {
    final picked =
        await showTimePicker(context: context, initialTime: isStart ? _start : _end);
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_technicianId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาเลือกช่างผู้รับงาน")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final startTime =
          DateTime(now.year, now.month, now.day, _start.hour, _start.minute);
      final endTime =
          DateTime(now.year, now.month, now.day, _end.hour, _end.minute);
      final dateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      await FirebaseFirestore.instance.collection('jobs').add({
        'technicianId': _technicianId,
        'customer': _customer.text.trim(),
        'phone': _phone.text.trim(),
        'service': _service.text.trim(),
        'serviceType': _service.text.trim(),
        'place': _place.text.trim(),
        'location': _place.text.trim(),
        'mapUrl': null,
        'date': dateStr,
        'month': _months[now.month - 1],
        'start': _fmt(_start),
        'end': _fmt(_end),
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'createdAt': Timestamp.fromDate(now),
        'status': 'assigned',
        'notificationType': 'newJob',
        'priority': 'normal',
        'isNotificationRead': false,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("มอบหมายงานเรียบร้อย")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("บันทึกไม่สำเร็จ: $e")),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text("มอบหมายงานใหม่"),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Technician picker
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('technicians').snapshots(),
              builder: (context, snap) {
                final items = <DropdownMenuItem<String>>[];
                if (snap.hasData) {
                  for (final d in snap.data!.docs) {
                    final data = d.data() as Map<String, dynamic>;
                    items.add(DropdownMenuItem(
                      value: d.id,
                      child: Text("${data['name'] ?? ''}  (${data['phone'] ?? ''})"),
                    ));
                  }
                }
                return DropdownButtonFormField<String>(
                  initialValue: _technicianId,
                  decoration: _dec("ช่างผู้รับงาน", Icons.engineering),
                  items: items,
                  onChanged: (v) => setState(() => _technicianId = v),
                  validator: (v) => v == null ? "กรุณาเลือกช่าง" : null,
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customer,
              decoration: _dec("ชื่อลูกค้า", Icons.person),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "กรอกชื่อลูกค้า" : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _dec("เบอร์ลูกค้า (ไม่บังคับ)", Icons.phone),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _service,
              decoration: _dec("บริการ (เช่น ล้างแอร์)", Icons.build),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "กรอกบริการ" : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _place,
              decoration: _dec("สถานที่/ที่อยู่", Icons.place),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _timeField("เริ่ม", _start, () => _pickTime(true))),
                const SizedBox(width: 12),
                Expanded(child: _timeField("จบ", _end, () => _pickTime(false))),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("มอบหมายงาน",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  Widget _timeField(String label, TimeOfDay t, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: _dec(label, Icons.schedule),
        child: Text(_fmt(t), style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
