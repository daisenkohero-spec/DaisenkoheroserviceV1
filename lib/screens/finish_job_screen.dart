import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/job_provider.dart';
import '../models/job_model.dart';
import 'nav_screen.dart';

class FinishJobScreen extends StatefulWidget {
  final Job job;
  const FinishJobScreen({super.key, required this.job});

  @override
  State<FinishJobScreen> createState() => _FinishJobScreenState();
}

class _FinishJobScreenState extends State<FinishJobScreen> {
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();
  XFile? _image;

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0 && mins > 0) {
      return "$hours ชั่วโมง $mins นาที";
    } else if (hours > 0) {
      return "$hours ชั่วโมง";
    } else {
      return "$mins นาที";
    }
  }

  /// ===== DESIGN SYSTEM  =====
  static const primaryColor = Color(0xFF1E3A8A); // Indigo 800
  static const accentColor = Color(0xFF1E40AF); // Indigo 700
  static const bgColor = Color(0xFFF1F5F9);
  static const cardRadius = 24.0;

  /// ================= IMAGE =================
  Future<void> _pickImage() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);

    if (img == null) return;

    setState(() {
      _image = img;
    });
  }

  /// ================= SUBMIT =================
  Future<void> _submitFinishJob() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาถ่ายรูปก่อนยืนยันจบงาน")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final jobProvider = context.read<JobProvider>();

    widget.job.startedWorkingAt ??= DateTime.now();

    widget.job.finishedAt = DateTime.now();
    widget.job.status = JobStatus.completed;
    widget.job.imagePath = _image!.path;

    await jobProvider.updateJob(widget.job);
    //  รีเฟรชหน้าเดิมแทน push ใหม่
    Navigator.pop(context);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const NavScreen(initialIndex: 2)),
      (route) => false,
    );
  }

  /// ================= TIME =================
  DateTime? _parseStartTime() {
    if (widget.job.start == null) return null;

    try {
      final parts = widget.job.start!.split(':');
      final now = DateTime.now();

      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    } catch (_) {
      return null;
    }
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final startTime = widget.job.startedWorkingAt;
    final endTime = DateTime.now();

    final durationMin = startTime == null
        ? null
        : endTime.difference(startTime).inMinutes.abs();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(.3),
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
                    color: Colors.white.withOpacity(.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              const Spacer(),
              const Text(
                "Finish Job",
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
      body: Column(
        children: [
          /// ===== CONTENT (SCROLL ได้) =====
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /// SUCCESS STATUS
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: accentColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "งานเสร็จสิ้นแล้ว",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Text(
                    "รายละเอียดงาน",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),

                  /// INFO CARD
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.job.customer,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.job.service,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),

                        _row("เริ่มงาน", widget.job.start ?? "--:--"),
                        const SizedBox(height: 12),
                        _row("จบงาน", _formatTime(endTime)),

                        if (durationMin != null) ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "เวลาที่ใช้",
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  _formatDuration(durationMin),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  /// PHOTO CARD
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "รูปงานที่สำเร็จ",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (_image == null)
                          OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("ถ่ายรูปงาน"),
                          )
                        else
                          Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  File(_image!.path),
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _pickImage,
                                child: const Text("ถ่ายใหม่"),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          /// ===== FIXED BUTTON =====
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            color: bgColor,
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitFinishJob,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "ยืนยันจบงาน",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ===== UI HELPERS =====
  Widget _card(Widget child) {
    return Container(
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
      child: child,
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: highlight ? accentColor : primaryColor,
          ),
        ),
      ],
    );
  }
}
