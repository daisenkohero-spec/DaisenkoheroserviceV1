import 'package:flutter/material.dart';

class AppAlert {
  /// ================= ระยะเกิน =================
  static void showCannotCheckIn(
    BuildContext context, {
    required double distance,
    required double allowedRadius,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off, color: Colors.red, size: 50),
                const SizedBox(height: 16),
                const Text(
                  "ไม่สามารถเช็กอินได้",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  distance >= 1000
                      ? "คุณอยู่ห่างจากสำนักงาน ${(distance / 1000).toStringAsFixed(2)} กม.\nอนุญาตไม่เกิน ${allowedRadius.toStringAsFixed(0)} เมตร"
                      : "คุณอยู่ห่างจากสำนักงาน ${distance.toStringAsFixed(0)} เมตร\nอนุญาตไม่เกิน ${allowedRadius.toStringAsFixed(0)} เมตร",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("ตกลง"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ================= Alert ทั่วไป =================
  static void showMessage(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "ตกลง",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
