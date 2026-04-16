//DHS Code for UI

# 📱 Techniqian App

แอปพลิเคชันสำหรับจัดการงานบริการช่างล้างแอร์ (Technician Management System)  
พัฒนาด้วย Flutter สำหรับโปรเจคฝึกงาน เพื่อช่วยให้ช่างสามารถจัดการงาน ตรวจสอบสถานะ และเช็คอินการทำงานได้อย่างมีประสิทธิภาพ

---

## 🚀 Features

-  **Authentication**  
  Login และจัดเก็บ Token ด้วย SharedPreferences  

-  **Dashboard (Home)**  
  แสดงภาพรวมงาน ปุ่ม Check-in แจ้งเตือน และสถิติการเข้างานรายเดือน  

-  **Job Management**  
  ดูรายการงาน (ปัจจุบัน / ล่วงเวลา / งานถัดไป) และรายละเอียดงาน  

-  **Check-in System**  
  เช็คอินตามตำแหน่ง พร้อมตรวจสอบระยะห่าง  

-  **Map Navigation**  
  แสดงเส้นทางไปยังจุดให้บริการ  

-  **Notifications**  
  แจ้งเตือนผ่าน Firebase Cloud Messaging และ Local Notification  

-  **Finish Job**  
  แนบรูปภาพหลังทำงานเสร็จ  

-  **Summary Report**  
  สรุปงานที่เสร็จ พร้อมดูข้อมูลย้อนหลังและรูปภาพ  

---


###  Main Workflow

1. ลูกค้าจองบริการ (Booking)  
2. ข้อมูลถูกบันทึกใน Firebase (collection: `booking`)  
3. แอดมินสร้างงานใน `jobs`  
4. แอปช่างดึงข้อมูลแบบ Real-time  
5. ช่างเห็นงานใหม่ในแอป  
6. ระบบส่ง Notification  
7. ช่างดำเนินงาน (รับงาน / เริ่มงาน / เสร็จงาน)  

---

###  Notification Flow

- มีการสร้าง Job ใหม่  
→ `notificationType = newJob`  
→ `isNotificationRead = false`  
→ แอปตรวจจับข้อมูล  
→ แสดง Notification บนเครื่อง  

---

##  Tech Stack

- Flutter (UI)  
- Provider (State Management)  
- Firebase  
  - Firestore (Database)  
  - Firebase Messaging (Push Notification)  
- SharedPreferences (Token Storage)  

---

## 📂 Project Structure

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

