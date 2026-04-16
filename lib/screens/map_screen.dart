import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/job_model.dart';
import 'finish_job_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/job_provider.dart';

enum MapJobState { started, onTheWay, canArrive, arrived }

class MapScreen extends StatefulWidget {
  final Job job;
  const MapScreen({super.key, required this.job});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const double arrivalRadiusKm = 0.07; // 50m
  static const double mockSpeedKmh = 40;
  StreamSubscription<Position>? _positionStream;
  GoogleMapController? _controller;
  MapJobState _mapState = MapJobState.started;

  double _etaMinutes = 0;
  double _remainingDistance = 0.0;
  double _currentZoom = 16;

  bool _mapReady = false;

  bool _noteExpanded = false;

  late LatLng customerLocation;
  LatLng _current = const LatLng(13.736717, 100.523186);

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  // ===== THEME =====
  static const primary = Color(0xFF1E3A8A);
  static const accent = Color(0xFF0EA5E9);
  static const success = Color(0xFF22C55E);
  static const bg = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();

    widget.job.startTravel = DateTime.now();

    _updateJobStatus("traveling");
    _sendStartTravel();

    customerLocation = _safeParseLatLng(widget.job.mapUrl ?? "");

    _setupMap();
    _buildRoute();
    _startRealLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // ================= MAP =================

  void _setupMap() {
    _markers.add(
      Marker(markerId: const MarkerId('customer'), position: customerLocation),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('tech'),
        position: _current,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    );
  }

  void _buildRoute() {
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: [_current, customerLocation],
      color: accent,
      width: 5,
      jointType: JointType.round,
    );

    _polylines.clear();
    _polylines.add(polyline);
  }

  void _onArrived() {
    setState(() {
      _mapState = MapJobState.arrived;
      widget.job.arrivedAt = DateTime.now();
    });

    context.read<JobProvider>().updateJob(
      widget.job..status = JobStatus.working,
    );

    _sendArrived();
  }
  //

  // ================= API MOCK =================

  Future<void> _sendStartTravel() async {
    await Future.delayed(const Duration(seconds: 1));
    debugPrint("Start travel sent ${widget.job.id}");
  }

  Future<void> _sendArrived() async {
    await Future.delayed(const Duration(seconds: 1));
    debugPrint("Arrived sent ${widget.job.id}");
  }

  Future<void> _sendFinish() async {
    await Future.delayed(const Duration(seconds: 1));
    //context.read<JobProvider>().completeJob(widget.job.id);
    debugPrint("Finish sent ${widget.job.id}");
  }

  Future<void> _updateJobStatus(String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.job.id)
          .update({
            "status": status,
            "assignedTo": "tech_001", // หรือใช้ id ของช่างจริง
            "updatedAt": FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint("Update status error: $e");
    }
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // เช็คว่า GPS เปิดไหม
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("GPS ยังไม่เปิด");
      return;
    }

    // ขอ permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("Permission ถูกปฏิเสธ");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Permission denied forever");
      return;
    }
  }

  void _startRealLocation() async {
    await _initLocation();

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5, // ขยับ 5 เมตรค่อย update
          ),
        ).listen((Position position) {
          final newLatLng = LatLng(position.latitude, position.longitude);

          setState(() {
            _current = newLatLng;

            _remainingDistance = _distance(newLatLng, customerLocation);
            _etaMinutes = (_remainingDistance / mockSpeedKmh) * 60;

            if (_mapState == MapJobState.started) {
              _mapState = MapJobState.onTheWay;
            }

            if (_remainingDistance <= arrivalRadiusKm &&
                _mapState == MapJobState.onTheWay) {
              _mapState = MapJobState.canArrive;
            }

            // update marker ช่าง
            _markers.removeWhere((m) => m.markerId.value == 'tech');
            _markers.add(
              Marker(
                markerId: const MarkerId('tech'),
                position: newLatLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure,
                ),
              ),
            );

            _buildRoute();
          });

          // เลื่อนกล้องตาม
          _controller?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: newLatLng, zoom: 17, tilt: 45, bearing: 0),
            ),
          );
        });
  }

  double _getBearing(LatLng start, LatLng end) {
    final lat1 = _deg(start.latitude);
    final lng1 = _deg(start.longitude);
    final lat2 = _deg(end.latitude);
    final lng2 = _deg(end.longitude);

    final dLng = lng2 - lng1;

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    return atan2(y, x) * 180 / pi;
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: customerLocation,
              zoom: 16,
            ),
            markers: _markers,
            polylines: _polylines,
            circles: {
              Circle(
                circleId: const CircleId("arrival"),
                center: customerLocation,
                radius: 50,
                strokeWidth: 3,
                strokeColor: _mapState == MapJobState.canArrive
                    ? Colors.green
                    : Colors.grey,
                fillColor: Colors.green.withOpacity(0.15),
              ),
            },
            onMapCreated: (c) {
              _controller = c;
              setState(() => _mapReady = true);
            },
          ),

          if (!_mapReady) const Center(child: CircularProgressIndicator()),

          SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          _routeOverlay(),
          _bottomSheet(),
        ],
      ),
    );
  }

  Widget _bottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.32,
      maxChildSize: 0.6,
      builder: (_, controller) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            children: [
              _timeline(),
              const SizedBox(height: 16),
              _jobCard(),
              const SizedBox(height: 20),
              _buildActionButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _timeline() {
    return Row(
      children: [
        _dotStep('เริ่มงาน', _fmt(widget.job.startTravel), true),
        _line(_mapState.index >= 1),
        _dotStep('กำลังเดินทาง', null, _mapState == MapJobState.onTheWay),
        _line(_mapState.index >= MapJobState.arrived.index),
        _dotStep(
          'ถึงที่หมาย',
          _fmt(widget.job.arrivedAt),
          _mapState == MapJobState.arrived,
        ),
      ],
    );
  }

  Widget _dotStep(String title, String? time, bool active) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: active ? accent : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontSize: 12)),
        if (time != null) Text(time, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _line(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        color: active ? accent : Colors.grey.shade300,
      ),
    );
  }

  Widget _jobCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER STRIP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text(
                  "งาน #${widget.job.id}",
                  style: TextStyle(
                    fontSize: 12,
                    color: primary.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "กำลังดำเนินการ",
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // CUSTOMER
          Text(
            widget.job.customer,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            widget.job.service,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),

          const SizedBox(height: 22),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 18),

          _infoRow(Icons.schedule, "เวลานัดหมาย", _fmt(widget.job.startTime)),
          const SizedBox(height: 14),

          _infoRow(Icons.location_on_outlined, "สถานที่", widget.job.place),
          const SizedBox(height: 14),

          _infoRow(Icons.phone_outlined, "เบอร์โทร", widget.job.phone),
          // ================= NOTE (EXPANDABLE) =================
          if (widget.job.customerNote != null &&
              widget.job.customerNote!.isNotEmpty) ...[
            const SizedBox(height: 18),
            Divider(color: Colors.grey.shade200),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: () {
                setState(() {
                  _noteExpanded = !_noteExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: accent),
                        const SizedBox(width: 8),
                        const Text(
                          "หมายเหตุจากลูกค้า",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _noteExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: accent,
                        ),
                      ],
                    ),

                    if (_noteExpanded) ...[
                      const SizedBox(height: 10),
                      Text(
                        widget.job.customerNote!,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _routeOverlay() {
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "กำลังเดินทาง",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 6),

            Row(
              children: const [
                Icon(Icons.my_location, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text(
                  "ตำแหน่งปัจจุบันของคุณ",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.job.customer,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),

            const Divider(color: Colors.white24, height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_remainingDistance.toStringAsFixed(2)} km",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "ถึงใน ${_etaMinutes.toStringAsFixed(0)} นาที",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    final isFinish = _mapState == MapJobState.arrived;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isFinish
              ? [primary, const Color(0xFF0F172A)]
              : [accent, primary],
        ),
        boxShadow: [
          BoxShadow(
            color: (isFinish ? primary : accent).withOpacity(0.35),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: () async {
          if (!isFinish) {
            _onArrived();
          } else {
            await context.read<JobProvider>().completeJob(widget.job.id);
            await _sendFinish();
            final ok = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FinishJobScreen(job: widget.job),
              ),
            );
            if (ok == true) {
              Navigator.pop(context, true);
            }
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFinish ? Icons.check_circle : Icons.location_on,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              isFinish ? "จบงานและอัปโหลดหลักฐาน" : "ยืนยันถึงสถานที่",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= UTILS =================

  String _fmt(DateTime? d) =>
      d == null ? '--:--' : '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  double _distance(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _deg(b.latitude - a.latitude);
    final dLng = _deg(b.longitude - a.longitude);
    final h =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg(a.latitude)) *
            cos(_deg(b.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(h), sqrt(1 - h));
  }

  double _deg(double d) => d * pi / 180;

  LatLng _safeParseLatLng(String url) {
    try {
      final uri = Uri.parse(url);
      final q = uri.queryParameters['q'];
      if (q == null) throw Exception();
      final p = q.split(',');
      return LatLng(double.parse(p[0]), double.parse(p[1]));
    } catch (_) {
      return const LatLng(13.7563, 100.5018);
    }
  }
}
