import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/attendance_provider.dart';
import 'dart:async';
import '../widgets/app_alert.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final DateTime _today = DateTime.now().toLocal();

  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  late Timer _timer;
  TimeOfDay _currentTime = TimeOfDay.fromDateTime(DateTime.now().toLocal());

  CheckinType _type = CheckinType.normal;
  final TextEditingController _reasonController = TextEditingController();

  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color accentColor = Color(0xFF0EA5E9);
  static const Color bgColor = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _focusedDay = _today;
    _selectedDay = _today;
    _currentTime = TimeOfDay.fromDateTime(DateTime.now().toLocal());

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _currentTime = TimeOfDay.fromDateTime(DateTime.now().toLocal());
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() async {
    try {
      final attendance = context.read<AttendanceProvider>();

      if (!isSameDay(_selectedDay, DateTime.now())) {
        AppAlert.showMessage(
          context,
          title: "ไม่สามารถเลือกวันอื่นได้",
          message: "กรุณาเช็คอินเฉพาะวันนี้",
        );
        return;
      }
      const Color dangerColor = Color.fromARGB(255, 189, 43, 43);
      if (_type == CheckinType.normal) {
        final now = DateTime.now();

        if (now.hour >= 9) {
          _type = CheckinType.late;
        }
      }
      //  เช็ค location สำหรับ normal + late
      if (_type != CheckinType.leave) {
        double distance = await attendance.getDistanceFromOffice();

        if (distance > AttendanceProvider.allowedRadius) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// ICON
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Color.fromARGB(
                            255,
                            189,
                            43,
                            43,
                          ).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_off,
                          color: Color.fromARGB(255, 189, 43, 43),
                          size: 32,
                        ),
                      ),

                      const SizedBox(height: 20),

                      ///  TITLE
                      Text(
                        "ไม่สามารถเช็คอินได้",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 189, 43, 43),
                        ),
                      ),

                      const SizedBox(height: 8),

                      /// DETAIL
                      Text(
                        "คุณอยู่นอกพื้นที่ (${attendance.formatDistance(distance)})\n"
                        "อนุญาตไม่เกิน ${attendance.formatDistance(AttendanceProvider.allowedRadius)}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 28),

                      /// BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dangerColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "ตกลง",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
          return;
        }
      }

      /// ================= เช็คเหตุผลการลา =================
      if (_type == CheckinType.leave && _reasonController.text.isEmpty) {
        AppAlert.showMessage(
          context,
          title: "กรอกข้อมูลไม่ครบ",
          message: "กรุณากรอกเหตุผลการลา",
        );
        return;
      }

      /// ================= บันทึกเช็คอิน =================
      attendance.checkIn(type: _type, reason: _reasonController.text);

      Navigator.pop(context);
    } catch (e) {
      AppAlert.showMessage(
        context,
        title: "ไม่สามารถดำเนินการได้",
        message: e.toString().replaceAll("Exception: ", ""),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendance = context.watch<AttendanceProvider>();

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          /// ================= HEADER =================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ///  แถวบน (Back + Title มีเงา)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "เช็กอินเข้างาน",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// 🔹 เวลา
                Center(
                  child: Column(
                    children: [
                      Text(
                        "${_currentTime.hour.toString().padLeft(2, '0')}:"
                        "${_currentTime.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "เวลาปัจจุบัน",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  /// ================= TYPE SELECT =================
                  Row(
                    children: [
                      Expanded(
                        child: _typeButton("เข้างาน", CheckinType.normal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _typeButton("ลา", CheckinType.leave)),
                    ],
                  ),

                  const SizedBox(height: 14),

                  /// ================= CALENDAR CARD =================
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.05),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,

                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },

                      selectedDayPredicate: (day) =>
                          isSameDay(day, _selectedDay),

                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },

                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, date, _) {
                          final status = attendance.getStatus(date);
                          final isSelected = isSameDay(date, _selectedDay);
                          final isToday = isSameDay(date, DateTime.now());

                          Color borderColor = Colors.transparent;

                          if (status != null) {
                            borderColor = attendance
                                .getStatusColor(status)
                                .withOpacity(0.6);
                          }

                          return Center(
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? primaryColor
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isToday ? primaryColor : borderColor,
                                    width: (isToday || status != null) ? 1 : 0,
                                  ),
                                ),
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: isToday
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  /// ================= LEAVE REASON =================
                  if (_type == CheckinType.leave)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          hintText: "กรอกเหตุผลการลา",
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                  const SizedBox(height: 18),

                  /// ================= SUBMIT BUTTON =================
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "ยืนยันเช็กอิน",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeButton(String label, CheckinType value) {
    final selected = _type == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _type = value;
          _reasonController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primaryColor.withOpacity(.4)),
          boxShadow: selected
              ? [BoxShadow(color: primaryColor.withOpacity(.3), blurRadius: 8)]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
