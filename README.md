# TravelMate

TravelMate is a Flutter-based travel planning and trip management application that helps users plan, organize, and manage their complete trip from one place.

The application combines trip planning, itineraries, bookings, locations, checklists, notes, expenses, offline storage, and cloud synchronization into a single travel management platform.

---

## 📱 About the Application

TravelMate is designed to make travel planning simple and organized.

Instead of using separate applications for itineraries, bookings, notes, expenses, maps, and checklists, TravelMate brings these features together under a single trip dashboard.

Users can create a trip and manage all related information from one place.

---

## ✨ Key Features

* **Trip Creation** – Create and manage travel trips with important trip details.
* **Trip Search** – Search and access existing trips.
* **Trip Dashboard** – Central dashboard providing access to all trip-management features.
* **Day-Wise Itinerary** – Organize activities and plans according to individual days.
* **Visual Itinerary** – View the trip plan in a visual and organized format.
* **Customised Itinerary** – Customize the itinerary according to travel requirements.
* **Collaborative Trip Editing** – Manage and update trip information collaboratively.
* **Trip Members** – Manage people participating in a trip.
* **Booking Master Folder** – Store and organize booking confirmations and travel documents.
* **Offline Storage** – Access important trip information even without an internet connection.
* **Firebase Synchronization** – Synchronize trip data with Firebase Realtime Database when online.
* **Google Maps Integration** – Save locations and open them directly in Google Maps.
* **Road Trip Planner** – Plan road trips, routes, and stops.
* **Packing Checklist** – Create and manage items that need to be packed.
* **Travel To-Do List** – Manage tasks and activities related to a trip.
* **Travel Notes** – Store important travel notes and information.
* **Expense Tracking** – Record and monitor trip-related expenses.
* **Online/Offline Status** – Display the current connection and synchronization status.
* **Responsive UI** – Designed to work across different mobile screen sizes.

---

# 🛠️ Technology Stack

### Frontend

* Flutter
* Dart
* Material Design

### Backend / Cloud

* Firebase Realtime Database
* Firebase Authentication (where configured)

### Local Storage

* SQLite
* Local offline storage

### External Services

* Google Maps
* File Picker
* External file opening

### Development Tools

* Visual Studio Code
* Flutter SDK
* Android Studio
* Firebase Console
* Git & GitHub

---

# 📂 Project Structure

```text
travelmate/
│
├── android/
├── ios/
├── lib/
│   │
│   ├── main.dart
│   ├── app_theme.dart
│   ├── models.dart
│   ├── storage_service.dart
│   ├── firebase_service.dart
│   ├── sync_service.dart
│   │
│   ├── splash_screen.dart
│   ├── trip_search_screen.dart
│   ├── trip_creation_screen.dart
│   ├── trip_dashboard_screen.dart
│   │
│   ├── day_wise_itinerary_screen.dart
│   ├── visual_itinerary_screen.dart
│   ├── customised_itinerary_screen.dart
│   ├── collaborative_editing_screen.dart
│   │
│   ├── trip_members_screen.dart
│   ├── booking_master_folder_screen.dart
│   ├── offline_storage_screen.dart
│   ├── google_maps_screen.dart
│   │
│   ├── road_trip_planner_screen.dart
│   ├── packing_checklist_screen.dart
│   ├── travel_todo_screen.dart
│   ├── travel_notes_screen.dart
│   ├── expense_tracking_screen.dart
│   │
│   └── app_navigation.dart
│
├── test/
├── pubspec.yaml
└── README.md
```

---

# 📥 Download the Project

Clone the repository using Git:

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
```

Move into the project directory:

```bash
cd travelmate
```

You can also download the project as a ZIP file from GitHub:

```text
GitHub Repository
        ↓
      Code
        ↓
   Download ZIP
        ↓
  Extract the project
```

---

# 📋 Prerequisites

Before running TravelMate, make sure the following are installed:

* Flutter SDK
* Dart SDK
* Android Studio
* Android SDK
* Git
* Visual Studio Code (recommended)
* Android Emulator or physical Android device

Check your Flutter installation:

```bash
flutter doctor
```

---

# 📦 Install Dependencies

After downloading or cloning the project, open the project directory and run:

```bash
flutter pub get
```

This installs all dependencies required by TravelMate.

---

# 🔥 Firebase Configuration

TravelMate uses **Firebase Realtime Database** for cloud data storage and synchronization.

If the Firebase configuration files are already included in the project, the application can use the configured Firebase project.

For a new Firebase setup, configure Firebase using:

```bash
flutterfire configure
```

Make sure the required Firebase services and Android configuration are correctly connected before running the application.

---

# ▶️ Run the Application

Check the available devices:

```bash
flutter devices
```

Then run:

```bash
flutter run
```

To run specifically on an Android emulator:

```bash
flutter run -d emulator-5554
```

Replace `emulator-5554` with the device ID shown by `flutter devices`.

---

# 📱 Run on a Physical Android Device

1. Enable **Developer Options** on your Android phone.
2. Enable **USB Debugging**.
3. Connect the phone to your computer.
4. Check that Flutter detects the device:

```bash
flutter devices
```

5. Run the application:

```bash
flutter run
```

---

# 🧭 How to Use TravelMate

### 1. Launch TravelMate

Open the application and wait for the splash screen to complete.

### 2. Create a Trip

Create a new trip by entering the required trip details.

### 3. Open the Trip Dashboard

Select a trip to open its dashboard.

The dashboard provides access to the different travel-management features.

### 4. Plan Your Itinerary

Use the itinerary features to organize activities and plans for each day of the trip.

### 5. Manage Trip Members

Add or manage people associated with the trip using the Trip Members feature.

### 6. Manage Bookings

Use the Booking Master Folder to store and organize booking confirmations and travel documents.

### 7. Save Locations

Use the Google Maps feature to save important locations and open them in Google Maps.

### 8. Plan a Road Trip

Use the Road Trip Planner to organize destinations, stops, and routes.

### 9. Manage Packing

Use the Packing Checklist to keep track of items that need to be packed.

### 10. Manage Travel Tasks

Use the Travel To-Do List to manage tasks that need to be completed before or during the trip.

### 11. Add Travel Notes

Use Travel Notes to save important information, reminders, and other trip-related notes.

### 12. Track Expenses

Use Expense Tracking to record and monitor trip-related expenses.

### 13. Use Offline Storage

Access supported trip information even when an internet connection is unavailable.

When the connection becomes available, supported data can synchronize with Firebase.

---

# 🔄 Data & Synchronization

TravelMate combines local storage with Firebase Realtime Database.

```text
                    TravelMate
                         │
                         ▼
                Flutter Application
                         │
                ┌────────┴────────┐
                │                 │
                ▼                 ▼
        Local Storage      Firebase Realtime
          (SQLite)             Database
                │                 │
                └────────┬────────┘
                         │
                   Sync Service
                         │
                         ▼
                  Updated Data
```

### Online Workflow

```text
User Action
     ↓
Flutter Application
     ↓
Local Storage
     ↓
Firebase Realtime Database
```

### Offline Workflow

```text
User Action
     ↓
Flutter Application
     ↓
Local Storage
     ↓
Data available offline
     ↓
Internet connection restored
     ↓
Synchronization
     ↓
Firebase Realtime Database
```

---

# 🧪 Testing

Run Flutter's analyzer to check the project:

```bash
flutter analyze
```

Then run the application:

```bash
flutter run
```

Test the following major functionality:

* Trip creation
* Trip search
* Trip dashboard
* Itinerary management
* Trip members
* Booking management
* Offline storage
* Firebase synchronization
* Google Maps
* Road trip planning
* Packing checklist
* Travel To-Do list
* Travel Notes
* Expense Tracking
* Different mobile screen sizes

---

# 📦 Build Android APK

To create a release APK:

```bash
flutter build apk --release
```

The generated APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

The APK can be shared directly with testers or uploaded to Google Drive for distribution.

---

# 🌐 Build Web Version

TravelMate can also be built for the web:

```bash
flutter build web
```

The generated web files will be located at:

```text
build/web/
```

These files can be deployed to a suitable web-hosting service such as GitHub Pages or Firebase Hosting.

---

# ⚠️ Important Notes

* Make sure Flutter and Android SDK are correctly configured before running the project.
* Firebase configuration must match the Firebase project used by the application.
* Do not upload private credentials, passwords, signing keys, or other sensitive information to GitHub.
* Keep Android release keystores and passwords secure.
* Google Maps and file-related features may require the appropriate permissions or external applications.
* Some features may behave differently depending on the platform.

---

# 🎯 Project Objective

The main objective of TravelMate is to provide an **all-in-one travel planning and management platform**.

Instead of using separate applications for itineraries, bookings, maps, checklists, notes, and expenses, TravelMate brings these functions together into a single application.

This makes travel planning more organized, accessible, and convenient for users.

---

# 🚀 Future Enhancements

Possible future improvements include:

* AI-powered itinerary generation
* Weather information
* Flight and hotel API integration
* Push notifications
* Expense splitting between trip members
* Advanced real-time collaboration
* Route optimization
* Travel recommendations
* Trip sharing
* Enhanced analytics and expense reports

---

# 👨‍💻 Development

TravelMate is developed using **Flutter and Dart**, with **Firebase Realtime Database** for cloud data management and local storage for offline functionality.

The application follows a modular architecture where screens, models, storage, Firebase services, synchronization, navigation, and UI components are separated into dedicated files.

---

# 📄 License

This project is developed as an educational/software project.

Add an appropriate license here if you plan to distribute the project publicly.

---

## TravelMate

**Plan • Organize • Explore • Together**
