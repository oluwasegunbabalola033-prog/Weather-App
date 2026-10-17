# 🌦️ Live Weather Forecast App

A modern, responsive, and cross-platform weather application built with **Flutter**, featuring real-time GPS meteorological tracking, interactive world maps, dual-API redundancy, animated vector graphics, Google Firebase Authentication, and automated hourly push notifications.

---

## 📱 Table of Contents
- [Key Features](#-key-features)
- [Architecture & Tech Stack](#-architecture--tech-stack)
- [Project Directory Structure](#-project-directory-structure)
- [Deep Dive into Screens & Functionality](#-deep-dive-into-screens--functionality)
  - [1. Authentication & Onboarding (`lib/signup.dart`)](#1-authentication--onboarding-libsignupdart)
  - [2. Weather Dashboard (`lib/weather.dart`)](#2-weather-dashboard-libweatherdart)
  - [3. Interactive Map & Global Search (`lib/map.dart`)](#3-interactive-map--global-search-libmapdart)
  - [4. Central Navigation & Auth Gateway (`lib/main.dart` & `lib/routes.dart`)](#4-central-navigation--auth-gateway-libmaindart--libroutesdart)
- [Notification Engine](#-notification-engine)
- [Weather API & Fallback Strategy](#-weather-api--fallback-strategy)
- [Getting Started & Installation](#-getting-started--installation)
- [Permissions & Configuration](#-permissions--configuration)

---

## ✨ Key Features

- **🔐 Firebase Google Authentication:**
  - One-tap sign-in with Google via native account picker.
  - State persistence using `StreamBuilder` connected to `FirebaseAuth.instance.authStateChanges()`.
  - Account drawer showing profile picture, display name, verified email badge, and email verification triggers.
  - Complete session clearing on logout (clears both Firebase session and cached Google accounts).

- **📍 Real-Time Location & Geocoding:**
  - Automatic GPS coordinate resolution via `geolocator`.
  - Continuous movement tracking with battery-efficient distance filters.
  - Reverse geocoding via `geocoding` translating coordinates into exact city/district and country names.

- **🎨 Fluid Animations & Canvas Graphics:**
  - Custom `CustomPainter` weather canvas on the login screen with bobbing cloud vectors, sun glows, and falling rain streaks.
  - Dynamic weather hero card on the home screen with condition-specific physics animations (rotating suns, floating clouds, pulsing rain, jittering thunderstorms).

- **🕒 8-Hour Hourly & 10-Day Daily Forecasts:**
  - Horizontal scrollable hourly weather cards with temperature variation curves and rain probability percentages.
  - Vertical list of 10-day forecasts detailing temperature highs/lows, bar ranges, and descriptive weather icons.

- **🗺️ Interactive Map & Worldwide Search:**
  - Full-screen OpenStreetMap view powered by `flutter_map` and `latlong2`.
  - Search any city, country, or landmark worldwide with autofocus camera animation.
  - Tap-to-inspect: Tap anywhere on the globe to place a marker and instantly inspect its live temperature, humidity, and wind speed inside an animated floating weather card.

- **🔔 Automated Background Notifications:**
  - Automated recurring hourly weather alerts using `flutter_local_notifications` (`periodicallyShow`).
  - Interactive hourly forecast cards allowing users to preview or trigger manual weather notification alerts for specific hours.

---

## 🛠️ Architecture & Tech Stack

| Component | Library / Technology |
|---|---|
| **Framework** | Flutter (Dart SDK ^3.13.3) |
| **UI Design System** | Material 3 with Dynamic Light & Dark Mode |
| **Authentication** | Firebase Auth (`firebase_auth: ^5.7.0`) & `google_sign_in: ^6.2.2` |
| **Backend / Services** | Google Firebase (`firebase_core: ^3.6.0`) |
| **Location & GPS** | `geolocator: ^13.0.2` & `geocoding: ^3.0.0` |
| **Mapping Engine** | `flutter_map: ^7.0.0` & `latlong2: ^0.9.0` (OpenStreetMap tile server) |
| **Local Notifications** | `flutter_local_notifications: ^18.0.1` |
| **Network Requests** | `http: ^1.6.0` |
| **Primary Weather API** | [Tomorrow.io Realtime Weather API](https://www.tomorrow.io/) |
| **Fallback Weather API** | [OpenWeatherMap API](https://openweathermap.org/) |

---

## 📂 Project Directory Structure

```text
lib/
├── main.dart        # Application entry point, Theme config, and AuthGate router
├── routes.dart      # Centralized named navigation routes
├── signup.dart      # Welcome screen, animated CustomPainter canvas & Google Auth
├── weather.dart     # Main weather dashboard, hourly/daily forecast & notification service
└── map.dart         # Interactive OpenStreetMap screen, search bar & geocoding
```

---

## 🔍 Deep Dive into Screens & Functionality

### 1. Authentication & Onboarding (`lib/signup.dart`)
- **`WeatherPainter`**: Custom Canvas rendering high-performance mathematical vector paths for:
  - Ambient sun glow with radial gradients.
  - Soft multi-circle cloud vectors with specular highlights.
  - Animated falling rain streaks driven by a continuous 3-second `AnimationController`.
- **`signInWithGoogle()`**:
  - Signs out any stale Google session to ensure the native account picker always shows.
  - Obtains `accessToken` and `idToken` from Google.
  - Converts tokens into a Firebase `AuthCredential` and authenticates with Firebase.
- **`WeatherScreen`**: Clean, accessible onboarding screen displaying the animated banner and the custom Material 3 `GoogleButton`.

### 2. Weather Dashboard (`lib/weather.dart`)
- **Location Initialization & Tracking**:
  - Automatically requests runtime location permissions (`ACCESS_FINE_LOCATION`).
  - Fetches high-accuracy GPS coordinates, reverse geocodes the location, and updates weather data.
  - Continuously listens to position changes through `Geolocator.getPositionStream`.
- **Top Dynamic Hero Section (`Weather` widget)**:
  - Background color and emoji automatically react to the current weather condition (Clear, Clouds, Rain, Thunderstorm, Fog/Mist).
  - Floating background emojis bob around the hero container while the primary icon performs condition-tailored physics animations.
- **Hourly Forecast (`HourlySection` & `HourlyItemCard`)**:
  - Displays the next 8 hours in a horizontal bouncing scroll view.
  - Highlights the current hour card (`NOW`) with primary container accents.
  - Calculates temperature and precipitation probabilities.
- **10-Day Extended Forecast (`DailyForecastSection`)**:
  - Displays upcoming days with weekday names, weather icons, condition labels, and visual temperature bars comparing min and max temperatures.
- **Account Bottom Sheet**:
  - Tapping the user's avatar in the AppBar slides up an account management sheet displaying:
    - User's Google profile picture.
    - Full Name and Email.
    - Verified Account badge / Email verification option.
    - Quick-access sign-out button that clears both Firebase and Google sessions.

### 3. Interactive Map & Global Search (`lib/map.dart`)
- **`FlutterMap` OpenStreetMap Integration**:
  - Smooth pan and pinch-to-zoom capabilities.
  - Custom location pin icon with smooth animated transitions.
- **Worldwide Search Bar**:
  - Enter any city, country, or location name (e.g., "Paris", "Tokyo", "New York").
  - Geocodes text inputs into latitude and longitude via `locationFromAddress`.
  - Automatically moves and zooms the map camera to the found destination.
- **Tap-to-Inspect Coordinates**:
  - Tap any place on the map to place a pin.
  - Performs reverse geocoding to retrieve the address.
  - Fetches real-time weather and displays it inside the floating `AnimatedMapWeatherCard` (displaying temperature, weather condition, humidity, and wind speed).

### 4. Central Navigation & Auth Gateway (`lib/main.dart` & `lib/routes.dart`)
- **`AuthGate`**:
  - Uses `StreamBuilder` on `FirebaseAuth.instance.authStateChanges()`.
  - Automatically routes already authenticated users directly into the main `Home` weather dashboard.
  - Directs logged-out users to the `WeatherScreen` sign-in page without flickering.
- **Bottom Navigation Bar**:
  - Allows switching between the Weather Dashboard and the Map View.

---

## 🔔 Notification Engine

The application includes a `NotificationService` built on top of `flutter_local_notifications`:

1. **Automatic Hourly Forecasts**:
   - Every time weather data is fetched or updated, `NotificationService.startHourlyPeriodicNotifications(...)` is triggered.
   - Configures a repeating hourly alert (`RepeatInterval.hourly`) using Android's `inexactAllowWhileIdle` schedule mode to conserve battery while delivering updates.
2. **On-Demand Hourly Card Preview**:
   - Users can tap any individual hourly forecast card in the carousel to trigger a notification and confirmation SnackBar for that specific forecast time.

---

## 🌐 Weather API & Fallback Strategy

To ensure high availability and prevent rate-limiting or network downtime:
1. **Primary Request**: Queries the **Tomorrow.io Realtime API** for precise temperature and numerical weather codes.
2. **Redundancy Fallback**: If Tomorrow.io returns an error or fails network validation, the app falls back to **OpenWeatherMap API**, ensuring the user always receives accurate meteorological data.

---

## 🚀 Getting Started & Installation

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.13.3 or newer)
- Android Studio / VS Code with Flutter extensions
- Android device or emulator running API 21+

### Step-by-Step Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/weather_app.git
   cd weather_app
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   - Place your `google-services.json` file inside `android/app/`.
   - Ensure Google Sign-In is enabled in your Firebase Console under **Authentication → Sign-in method**.
   - Add your SHA-1 fingerprint to your Firebase Android App settings.

4. **Run the application:**
   ```bash
   flutter run
   ```

---

## 🛡️ Permissions & Configuration

The Android configuration includes the following permissions in `android/app/src/main/AndroidManifest.xml`:

- `android.permission.INTERNET`: For map tiles, Firebase authentication, and weather API requests.
- `android.permission.ACCESS_FINE_LOCATION` & `ACCESS_COARSE_LOCATION`: To fetch current GPS coordinates.
- `android.permission.POST_NOTIFICATIONS`: To show notifications on Android 13+ (API 33+).
- `android.permission.RECEIVE_BOOT_COMPLETED`: To re-schedule notifications after device reboots.
- `android.permission.SCHEDULE_EXACT_ALARM`: To support scheduled alarms and timely periodic weather updates.
- **Java 8+ Desugaring**: Enabled via `isCoreLibraryDesugaringEnabled = true` in `android/app/build.gradle.kts` for backward-compatible notification scheduling.

---

## 📄 License
This project is open-source and available under the [MIT License](LICENSE).
