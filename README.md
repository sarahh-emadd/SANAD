# SANAD - Smart Elderly Care System

Sanad is a smart elderly care system designed to support seniors living independently while giving caregivers peace of mind. The system combines IoT devices, AI-powered computer vision, and a cloud-based backend to monitor daily activities, detect emergencies, and ensure medication adherence — all in a respectful, non-intrusive way.

## 📁 Monorepo Structure
```
SANAD/
├── server/              # Backend API (Node.js/Express)
│   ├── config/
│   ├── models/
│   ├── routes/
│   ├── controllers/
│   ├── middleware/
│   ├── services/
│   └── server.js
├── mobile/              # Mobile App (Flutter)
│   ├── lib/
│   │   ├── config/
│   │   ├── models/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── widgets/
│   │   └── main.dart
│   └── pubspec.yaml
├── package.json         # Root scripts
└── README.md
```

## 🚀 Getting Started

### Prerequisites
- Node.js & npm
- Flutter SDK
- Database (PostgreSQL/MongoDB)

### Installation
```bash
# Install all dependencies
npm run install:all

# Or install individually
npm run install:server    # Backend only
npm run install:mobile    # Mobile only
```

### Running the Applications

**Backend Server:**
```bash
npm run server
# Runs on http://localhost:3000
```

**Mobile App:**
```bash
npm run mobile
# Or directly: cd mobile && flutter run
```

## 🔧 Configuration

### Backend (.env)
Create `server/.env`:
```
PORT=3000
DATABASE_URL=your_database_url
JWT_SECRET=your_jwt_secret
```

### Mobile (API Config)
Update `mobile/lib/config/api_config.dart`:
```dart
static const String baseUrl = 'http://localhost:3000';
```

## 🏗️ Key Features

### 🎥 AI Camera Monitoring
- Real-time human detection using YOLOv8
- Elderly selection & ID locking to avoid false alerts
- Fall detection based on motion, posture, and temporal analysis

### 📱 Mobile Application
- Real-time activity monitoring
- Emergency alerts and notifications
- Medication reminders
- Caregiver dashboard

### ☁️ Backend Services
- RESTful API
- Real-time data processing
- IoT device integration
- User authentication & authorization

## 👥 Team Collaboration

### Backend Team
Work in the `server/` directory
```bash
cd server
npm install
npm run dev
```

### Mobile Team
Work in the `mobile/` directory
```bash
cd mobile
flutter pub get
flutter run
```

## 📝 Git Workflow
```bash
# Pull latest changes
git pull origin main

# Create feature branch
git checkout -b feature/your-feature-name

# Make changes, then commit
git add .
git commit -m "Description of changes"

# Push and create PR
git push origin feature/your-feature-name
```

## 📄 License
[Add your license here]

## 👨‍💻 Contributors
[Add team members]
