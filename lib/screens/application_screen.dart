import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'nav_screen.dart';

/// ใบสมัครช่างใหม่ (หลังล็อกอินด้วย Google ที่ยังไม่ได้เป็นช่าง)
///
/// - ยังไม่ส่ง / ถูกปฏิเสธ -> กรอกแบบฟอร์ม
/// - ส่งแล้ว -> รอแอดมินตรวจสอบ
/// - แอดมินอนุมัติ -> เข้าแอปช่างอัตโนมัติ
class ApplicationScreen extends StatelessWidget {
  const ApplicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final ref = auth.repository.myApplicationRef;

    return Scaffold(
      backgroundColor: AppColors.bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        title: const Text("สมัครเป็นช่าง Daisenko Hero"),
        actions: [
          TextButton(
            onPressed: () => _backToLogin(context),
            child: const Text(
              "ออกจากระบบ",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: ref == null
          ? const Center(child: Text("กรุณาเข้าสู่ระบบด้วย Google อีกครั้ง"))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: ref.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snap.data?.data();
                final status = data?['status'] as String?;

                if (status == 'approved') {
                  return const _Approved();
                }
                if (status == 'pending') {
                  return _Pending(data: data!);
                }
                return _ApplicationForm(
                  previous: data,
                  rejectReason: status == 'rejected'
                      ? (data?['rejectReason'] ?? '').toString()
                      : null,
                );
              },
            ),
    );
  }
}

Future<void> _backToLogin(BuildContext context) async {
  await context.read<AuthProvider>().logout();
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

// -----------------------------------------------------------------------------
// แบบฟอร์ม
// -----------------------------------------------------------------------------

class _ApplicationForm extends StatefulWidget {
  const _ApplicationForm({this.previous, this.rejectReason});

  final Map<String, dynamic>? previous;
  final String? rejectReason;

  @override
  State<_ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends State<_ApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.previous?['name']?.toString() ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.previous?['phone']?.toString() ?? '',
  );
  late final _area = TextEditingController(
    text: widget.previous?['area']?.toString() ?? '',
  );
  late int _level =
      (widget.previous?['trainingLevelClaimed'] as num?)?.toInt() ?? 0;
  bool _agreed = false;
  bool _saving = false;

  static const _levels = {
    0: "ยังไม่ได้อบรม / กำลังจะอบรม",
    1: "Level 1 (ล้างแอร์)",
    2: "Level 2 (ล้าง + ซ่อม)",
    3: "Level 3 (ติดตั้ง + ออกแบบระบบ VRF)",
  };

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณายอมรับข้อตกลงก่อนส่งใบสมัคร")),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().submitApplication(
        name: _name.text,
        phone: _phone.text,
        area: _area.text,
        trainingLevel: _level,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ส่งใบสมัครไม่สำเร็จ: $e")),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final email = context.read<AuthProvider>().repository.currentEmail;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.rejectReason != null)
          _Banner(
            color: AppColors.error,
            icon: Icons.info_outline,
            text: widget.rejectReason!.isEmpty
                ? "ใบสมัครก่อนหน้าไม่ผ่าน แก้ไขแล้วส่งใหม่ได้"
                : "ใบสมัครก่อนหน้าไม่ผ่าน: ${widget.rejectReason}\nแก้ไขแล้วส่งใหม่ได้",
          ),
        _Banner(
          color: AppColors.primaryColor,
          icon: Icons.badge_outlined,
          text:
              "เป็นช่างที่มีบัญชีอยู่แล้ว? กด \"ออกจากระบบ\" แล้วเข้าด้วยเบอร์โทร จากนั้นแตะชื่อที่หน้า Home เพื่อเชื่อมบัญชี Google",
        ),
        const SizedBox(height: 8),
        Text(
          "บัญชี Google: $email",
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            children: [
              _field(_name, "ชื่อ-นามสกุล", Icons.person_outline,
                  validator: (v) =>
                      (v ?? '').trim().length < 4 ? "กรุณากรอกชื่อ-นามสกุล" : null),
              _field(_phone, "เบอร์โทร", Icons.phone_outlined,
                  keyboard: TextInputType.phone,
                  validator: (v) =>
                      RegExp(r'^0\d{8,9}$').hasMatch((v ?? '').trim())
                          ? null
                          : "เบอร์โทร 9–10 หลัก ขึ้นต้นด้วย 0"),
              _field(_area, "พื้นที่ที่รับงานได้ (เช่น บางนา, ลาดพร้าว)",
                  Icons.place_outlined,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? "กรุณาระบุพื้นที่" : null),
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                initialValue: _level,
                decoration: _decoration(
                  "ผลอบรม Daisenko",
                  Icons.workspace_premium_outlined,
                ),
                items: _levels.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _level = v ?? 0),
              ),
              const SizedBox(height: 6),
              const Text(
                "แอดมินจะตรวจสอบผลอบรมกับ Daisenko ก่อนเปิดรับงาน ช่างที่ยังไม่ผ่านอบรมสมัครได้ แต่จะยังไม่ได้รับงานจนกว่าจะผ่าน Level 1",
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  "ยอมรับจรรยาบรรณช่าง Daisenko Hero: งานและลูกค้าที่ได้จากระบบ จะรับและนัดผ่านระบบเท่านั้น",
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    disabledBackgroundColor: AppColors.buttonDisabled,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _saving ? "กำลังส่ง..." : "ส่งใบสมัคร",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        validator: validator,
        decoration: _decoration(label, icon),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.iconSecondary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );
}

// -----------------------------------------------------------------------------
// รออนุมัติ / อนุมัติแล้ว
// -----------------------------------------------------------------------------

class _Pending extends StatelessWidget {
  const _Pending({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.hourglass_top_rounded,
            size: 64, color: AppColors.warning),
        const SizedBox(height: 16),
        const Text(
          "ส่งใบสมัครแล้ว รอแอดมินตรวจสอบ",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          "เมื่ออนุมัติแล้ว หน้านี้จะพาเข้าแอปช่างให้อัตโนมัติ เปิดแอปค้างไว้หรือกลับมาเข้าสู่ระบบด้วย Google ภายหลังก็ได้",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ชื่อ: ${data['name'] ?? '-'}"),
                Text("เบอร์โทร: ${data['phone'] ?? '-'}"),
                Text("พื้นที่: ${data['area'] ?? '-'}"),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Approved extends StatefulWidget {
  const _Approved();

  @override
  State<_Approved> createState() => _ApprovedState();
}

class _ApprovedState extends State<_Approved> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_enter);
  }

  Future<void> _enter() async {
    final auth = context.read<AuthProvider>();
    await auth.completeApprovedSignup();
    if (!mounted) return;
    if (auth.isLoggedIn) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const NavScreen()),
        (route) => false,
      );
    } else if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 64, color: AppColors.success),
          SizedBox(height: 12),
          Text("อนุมัติแล้ว กำลังเข้าแอปช่าง..."),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text});

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
