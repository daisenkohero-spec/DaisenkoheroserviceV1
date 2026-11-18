import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/geo/geohash.dart';
import '../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

/// พื้นที่รับงาน (จุดฐาน + รัศมี) และใบรับรอง Daisenko ของช่าง
///
/// จุดฐานใช้หาว่าช่างครอบคลุมลูกค้าคนไหน (ไม่ใช่ GPS ตอนนี้ เพราะงานเป็นนัดล่วงหน้า)
/// ใบรับรองแอดมินเป็นคนบันทึก ช่างดูได้อย่างเดียว
class ServiceAreaScreen extends StatefulWidget {
  const ServiceAreaScreen({super.key});

  @override
  State<ServiceAreaScreen> createState() => _ServiceAreaScreenState();
}

class _ServiceAreaScreenState extends State<ServiceAreaScreen> {
  final _coords = TextEditingController();
  double? _lat, _lng;
  double _radiusKm = 15;
  bool _loading = true, _saving = false, _locating = false;
  Map<String, dynamic>? _cert;

  late final DocumentReference<Map<String, dynamic>> _ref = FirebaseFirestore
      .instance
      .collection('technicians')
      .doc(context.read<AuthProvider>().user!.id);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _coords.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _ref.get(),
        FirebaseFirestore.instance.collection('config').doc('booking').get(),
      ]);
      final tech = results[0].data() ?? {};
      final config = results[1].data() ?? {};
      final base = tech['base'] as Map<String, dynamic>?;
      setState(() {
        _lat = (base?['lat'] as num?)?.toDouble();
        _lng = (base?['lng'] as num?)?.toDouble();
        if (_lat != null) _coords.text = _fmt(_lat!, _lng!);
        _radiusKm = ((tech['radiusKm'] ?? config['defaultRadiusKm'] ?? 15) as num)
            .toDouble()
            .clamp(5.0, 50.0);
        _cert = tech['cert'] as Map<String, dynamic>?;
      });
    } catch (e) {
      _snack("โหลดข้อมูลไม่สำเร็จ: $e");
    }
    if (mounted) setState(() => _loading = false);
  }

  String _fmt(double lat, double lng) =>
      "${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}";

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack("ไม่ได้รับสิทธิ์เข้าถึงตำแหน่ง ลองวางพิกัดจาก Google Maps แทน");
      } else {
        final p = await Geolocator.getCurrentPosition();
        setState(() {
          _lat = p.latitude;
          _lng = p.longitude;
          _coords.text = _fmt(_lat!, _lng!);
        });
      }
    } catch (e) {
      _snack("หาตำแหน่งไม่สำเร็จ: $e");
    }
    if (mounted) setState(() => _locating = false);
  }

  /// รับพิกัดแบบที่ Google Maps คัดลอกให้ เช่น "13.756331, 100.501765"
  void _parseCoords(String text) {
    final m = RegExp(r'(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)').firstMatch(text);
    final lat = double.tryParse(m?.group(1) ?? '');
    final lng = double.tryParse(m?.group(2) ?? '');
    setState(() {
      if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) {
        _lat = lat;
        _lng = lng;
      } else {
        _lat = null;
        _lng = null;
      }
    });
  }

  Future<void> _openInMaps() async {
    if (_lat == null) return;
    await launchUrl(
      Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$_lat,$_lng",
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _save() async {
    if (_lat == null || _lng == null) {
      _snack("กรุณาตั้งจุดฐานก่อน");
      return;
    }
    setState(() => _saving = true);
    try {
      await _ref.update({
        'base': {
          'lat': _lat,
          'lng': _lng,
          'geohash': encodeGeohash(_lat!, _lng!),
        },
        'radiusKm': _radiusKm.round(),
        'baseUpdatedAt': FieldValue.serverTimestamp(),
      });
      _snack("บันทึกพื้นที่รับงานแล้ว");
    } catch (e) {
      _snack("บันทึกไม่สำเร็จ: $e");
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        title: const Text("พื้นที่รับงาน & ใบรับรอง"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                CertificateCard(cert: _cert),
                const SizedBox(height: 20),
                const Text(
                  "จุดฐาน (บ้านหรือร้านที่ออกไปรับงาน)",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 4),
                const Text(
                  "ระบบจะส่งงานที่อยู่ในรัศมีจากจุดนี้ ลูกค้าไม่เห็นตำแหน่งจุดฐานของคุณ",
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _locating ? null : _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      _locating ? "กำลังหาตำแหน่ง..." : "ใช้ตำแหน่งปัจจุบัน",
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _coords,
                  onChanged: _parseCoords,
                  decoration: InputDecoration(
                    labelText: "หรือวางพิกัดจาก Google Maps",
                    hintText: "เช่น 13.756331, 100.501765",
                    prefixIcon: const Icon(Icons.place_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _lat == null
                            ? "ยังไม่ได้ตั้งจุดฐาน"
                            : "จุดฐาน: ${_fmt(_lat!, _lng!)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: _lat == null
                              ? AppColors.error
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (_lat != null)
                      TextButton(
                        onPressed: _openInMaps,
                        child: const Text("ดูบนแผนที่"),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "รัศมีรับงาน: ${_radiusKm.round()} กม.",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Slider(
                  value: _radiusKm,
                  min: 5,
                  max: 50,
                  divisions: 45,
                  label: "${_radiusKm.round()} กม.",
                  onChanged: (v) => setState(() => _radiusKm = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      disabledBackgroundColor: AppColors.buttonDisabled,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _saving ? "กำลังบันทึก..." : "บันทึก",
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
    );
  }
}

/// สถานะใบรับรอง Daisenko (ใช้ทั้งแอปช่างและหลังบ้าน)
class CertificateCard extends StatelessWidget {
  const CertificateCard({super.key, required this.cert});

  final Map<String, dynamic>? cert;

  static const levelNames = {
    1: "Level 1 · ล้างแอร์",
    2: "Level 2 · ล้าง + ซ่อม",
    3: "Level 3 · ติดตั้ง + ออกแบบระบบ VRF",
  };

  @override
  Widget build(BuildContext context) {
    final level = (cert?['level'] as num?)?.toInt() ?? 0;
    final expires = cert?['expiresAt'] is Timestamp
        ? (cert!['expiresAt'] as Timestamp).toDate()
        : null;
    final daysLeft = expires?.difference(DateTime.now()).inDays;

    Color color;
    IconData icon;
    String status;
    if (level == 0) {
      color = AppColors.textSecondary;
      icon = Icons.school_outlined;
      status = "ยังไม่มีใบรับรอง จะได้รับงานหลังผ่าน Daisenko Level 1";
    } else if (daysLeft != null && daysLeft < 0) {
      color = AppColors.error;
      icon = Icons.error_outline;
      status = "หมดอายุแล้ว ระบบหยุดส่งงานให้ ติดต่อแอดมินเพื่อต่ออายุ";
    } else if (daysLeft != null && daysLeft <= 30) {
      color = AppColors.warning;
      icon = Icons.schedule;
      status = "จะหมดอายุใน $daysLeft วัน ติดต่อแอดมินเพื่อต่ออายุ";
    } else {
      color = AppColors.success;
      icon = Icons.verified;
      status = "ใช้งานได้";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level == 0
                      ? "ใบรับรอง Daisenko"
                      : "Daisenko ${levelNames[level] ?? 'Level $level'}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if (expires != null)
                  Text(
                    "หมดอายุ ${expires.day}/${expires.month}/${expires.year}",
                    style: const TextStyle(fontSize: 13),
                  ),
                Text(status, style: TextStyle(fontSize: 13, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
