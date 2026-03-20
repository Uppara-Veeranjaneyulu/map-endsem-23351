# Plant Care Companion

A comprehensive Flutter application to help you keep track of your plants and their watering schedules.

## depolyment

``
https://map-34c89.web.app/
``

## Features

- **Plant Gallery**: View all your plants in a beautifully designed grid interface.
- **Add & Manage Plants**: Add new plants with details like name, type (Indoor, Outdoor, Succulent, etc.), and custom images.
- **Watering Reminders**: Set custom watering frequencies for each plant, and the app will schedule local notifications to remind you when it's time to water them.
- **Location Tagging**: Tag the location of your plants using GPS coordinates or custom location names (e.g., "Balcony", "Living Room").
- **Search & Filter**: Easily find specific plants using the search functionality or filter them by plant type.
- **Firebase Integration**: Uses Cloud Firestore for real-time cloud data storage and sync.

## Tech Stack

- **Framework**: Flutter
- **State Management**: Provider
- **Backend/Database**: Firebase (Cloud Firestore)
- **Geolocation**: `geolocator` package
- **Notifications**: `flutter_local_notifications` for cross-platform local push notifications

## Getting Started

### Prerequisites

- Flutter SDK (version ^3.10.4 or higher)
- Dart SDK
- An active Firebase project

### Installation

1. Clone the repository:
   ```sh
   git clone <repository-url>
   ```

2. Navigate to the project directory:
   ```sh
   cd justpro
   ```

3. Install dependencies:
   ```sh
   flutter pub get
   ```

4. **Firebase Setup**:
   This project relies on Firebase. You need to configure it before running the app:
   - Create a Firebase project in the Firebase Console.
   - Register your Android/iOS apps in the project.
   - Use FlutterFire CLI to configure the project automatically:
     ```sh
     flutterfire configure
     ```
   - Make sure your Firestore rules are set up properly for development.

5. Run the application:
   ```sh
   flutter run
   ```

## Folder Structure

The main application code is located in the `lib` folder:
- `main.dart`: Contains the primary data models, state management logic (Provider), and the main UI screens (Gallery, Details, Add/Edit).
- `notifications_mobile.dart` & `notifications_web.dart`: Handle platform-specific local notification scheduling.
- `firebase_options.dart`: Automatically generated file for Firebase configuration.
