//DHS Code for UI

# Techniqian App

แอปพลิเคชันสำหรับจัดการงานช่างภาคสนาม (Technician Management System)  
พัฒนาด้วย Flutter สำหรับโปรเจคฝึกงาน

---

## Features

- Login (Mock API)
- Job Management (ดูงาน, สถานะงาน)
- Attendance / Check-in
- Notification (Firebase Cloud Messaging + Local Notification)
- Home/Dashboard (สรุปงานและสถานะ)

---

## Tech Stack

- Flutter (UI)
- Provider (State Management)
- Firebase
  - Firestore (Database)
  - Firebase Messaging (Push Notification)
- SharedPreferences (เก็บ Token)

---

## Project Structure
lib/
┣ models/
┣ providers/
┣ repositories/
┣ screens/
┣ services/
┗ core/

---

## ⚙️ How to Run

```bash
flutter pub get
flutter run

