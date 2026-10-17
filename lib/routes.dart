// ============================================================================
// FILE: lib/routes.dart
// PURPOSE: Centralized Navigation Route Definitions
// 
// NARRATION / ARCHITECTURE:
// - Contains route name constants to prevent string typos during navigation.
// - Maps route names to their corresponding Screen Widgets for MaterialApp.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:weather_app/map.dart';
import 'package:weather_app/signup.dart';
import 'package:weather_app/weather.dart';

/// Central static class containing named navigation routes and builders
class AppRoutes {
  /// Route name for Sign-Up / Login Screen
  static const String signup = '/signup';

  /// Route name for Home Weather Dashboard Screen
  static const String weather = '/weather';

  /// Route name for Interactive Map & Weather Search Screen
  static const String map = '/map';

  /// Map associating String route paths to WidgetBuilder functions
  static Map<String, WidgetBuilder> routes = {
    AppRoutes.signup: (context) => const WeatherScreen(),
    AppRoutes.weather: (context) => const Home(),
    AppRoutes.map: (context) => const MapScreen(),
  };
}
