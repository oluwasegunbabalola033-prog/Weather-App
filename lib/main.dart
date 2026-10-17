// ============================================================================
// FILE: lib/main.dart
// PURPOSE: Application Entry Point & Theme Configuration
// 
// NARRATION / ARCHITECTURE:
// - Initializes Flutter bindings & Firebase Core.
// - Sets up the global MaterialApp with Light & Dark Material 3 Theme Data.
// - Configures `AuthGate` to dynamically determine whether to open the 
//   Home Weather Screen (if logged in) or the Sign-In Screen (if logged out).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:weather_app/routes.dart';
import 'package:weather_app/signup.dart';
import 'package:weather_app/weather.dart';

/// App main execution function
void main() async {
  // Ensures Flutter framework widgets are bound before async native calls
  WidgetsFlutterBinding.ensureInitialized();

  // Initializes Firebase SDK services across Android/iOS
  await Firebase.initializeApp();

  // Launches the root Widget tree
  runApp(const MyApp());
}

/// Root Widget configuring Themes, Navigation Routes, and Auth Gateway
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Primary seed color used to generate the Material 3 Color Scheme
    const seedColor = Colors.blue;

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // Initial root widget dynamically determined by authentication state
      home: const AuthGate(),

      // Map of named navigation routes used for Navigator.pushNamed(...)
      routes: AppRoutes.routes,

      // Automatically follows the system Light/Dark theme preference
      themeMode: ThemeMode.system,

      // Light Theme configuration using Material 3 ColorScheme from seed
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
      ),

      // Dark Theme configuration with true black scaffold background
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
    );
  }
}

/// Authentication Gateway Widget
///
/// Listens to `FirebaseAuth.instance.authStateChanges()` stream:
/// - If user is logged in (`hasData`): Redirects directly to `Home` screen.
/// - If user is logged out: Redirects to `WeatherScreen` (Google Sign-In screen).
/// - While waiting for token: Renders a centered CircularProgressIndicator.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Connection loading state while reading stored token from device memory
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 2. User is logged in with valid Firebase token
        if (snapshot.hasData && snapshot.data != null) {
          return const Home();
        }

        // 3. User is logged out or unauthenticated
        return const WeatherScreen();
      },
    );
  }
}
