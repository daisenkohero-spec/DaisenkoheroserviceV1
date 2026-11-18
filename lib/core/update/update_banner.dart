import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'page_reload.dart';

/// รหัสของ build นี้ ใส่ตอน build ด้วย scripts/deploy-web.ps1
/// (`--dart-define=BUILD_ID=...`) และเขียนลงไฟล์ build_id.txt บนเว็บด้วย
const kBuildId = String.fromEnvironment('BUILD_ID', defaultValue: 'dev');

/// แถบ "มีเวอร์ชันใหม่" สำหรับเว็บ: เช็ก build_id.txt บนเซิร์ฟเวอร์ทุก 5 นาที
/// และทุกครั้งที่กลับมาที่แท็บ ถ้าไม่ตรงกับ build ที่เปิดอยู่ แสดงแถบให้แตะโหลดใหม่
/// (แก้ปัญหา Chrome ค้างเวอร์ชันเก่าหลัง deploy)
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner>
    with WidgetsBindingObserver {
  static const _interval = Duration(minutes: 5);

  Timer? _timer;
  bool _updateAvailable = false;

  bool get _enabled => kIsWeb && kBuildId != 'dev';

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_interval, (_) => _check());
    Future.delayed(const Duration(seconds: 10), _check);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_updateAvailable || !mounted) return;
    try {
      final uri = Uri.base.resolve(
        'build_id.txt?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final res = await http.get(uri);
      final latest = res.body.trim();
      if (res.statusCode == 200 &&
          latest.isNotEmpty &&
          latest.length < 64 &&
          latest != kBuildId &&
          mounted) {
        setState(() => _updateAvailable = true);
      }
    } catch (_) {
      // ออฟไลน์ชั่วคราว: ลองใหม่รอบหน้า
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_enabled) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_updateAvailable)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              child: Material(
                color: const Color(0xFF1E3A8A),
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: reloadPage,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.system_update_alt, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "มีเวอร์ชันใหม่ แตะเพื่อโหลด",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.refresh, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
