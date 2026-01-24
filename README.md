# SANAD
Sanad is a smart elderly care system designed to support seniors living independently while giving caregivers peace of mind. The system combines IoT devices, AI-powered computer vision, and a cloud-based backend to monitor daily activities, detect emergencies, and ensure medication adherence — all in a respectful, non-intrusive way.


# Key Features
👁️ AI Camera Monitoring

Real-time human detection and tracking using YOLOv8

Elderly selection & ID locking to avoid false alerts when others are present

Fall detection based on motion, posture, and temporal analysis

Emergency alerts sent only when the registered elderly person is involved

💊 Smart Pillbox

ESP32-based smart pillbox

Load cell + HX711 to detect whether medication was taken

Visual (LED) and audio (buzzer) reminders

Automatic notification to caregivers when a dose is missed or taken

🆘 SOS Emergency Button

Physical SOS button for manual emergency alerts

Works independently of camera detection

Instant notification to caregivers via backend services

☁️ Backend & Dashboard

Central backend to collect and process data from devices

Real-time alerts & event logging

Caregiver dashboard for monitoring status and history

Designed to be scalable and secure

# 🧠 Technologies Used

AI / Computer Vision: YOLOv8, OpenCV

IoT Hardware: ESP32, Load Cell, HX711, LEDs, Buzzer

Backend: REST APIs, Database (Firebase / Node.js / FastAPI – configurable)

Communication: Wi-Fi, HTTP / MQTT

Frontend (Planned): Mobile or Web dashboard for caregivers

# 🎯 Project Goals

Reduce elderly fall-related risks

Ensure medication adherence

Minimize false alarms

Provide caregivers with reliable, real-time insights

Build a low-cost, scalable solution suitable for real-world deployment

# 🏥 Use Case

Sanad is ideal for:

Elderly people living alone

Families caring for seniors remotely

Home-care services

Assisted living environments

# 🔮 Future Enhancements

Face recognition for automatic elderly identification

Activity pattern analysis

Mobile app notifications

Cloud analytics & reporting

# ❤️ Why “Sanad”?

Sanad means support in Arabic — reflecting the project’s mission to be a silent, reliable companion for the elderly and a trusted assistant for caregivers.
