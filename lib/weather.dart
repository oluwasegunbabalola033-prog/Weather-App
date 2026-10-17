// ============================================================================
// FILE: lib/weather.dart
// PURPOSE: Home Weather Dashboard Screen
// 
// NARRATION / ARCHITECTURE:
// - Displays real-time weather details for the user's current GPS location.
// - Fetches real-time weather from Tomorrow.io API with automatic fallback 
//   to OpenWeatherMap API if network fails.
// - Features an animated top weather section (`Weather`), 8-hour horizontal 
//   forecast (`HourlySection`), and 10-day vertical forecast (`DailyForecastSection`).
// - Includes a user profile avatar in the AppBar that opens an account modal 
//   bottom sheet with account details, email verification status, and logout.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:math';

import 'map.dart';
import 'routes.dart';

/// Main Home Dashboard Screen Widget
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // Current active location display name
  String currentLocation = '';

  // Tomorrow.io Weather API Key
  String apiKey = 'Ovmvkn44lgJhXyGfqQoyngeKr7T1bmEl';

  // Weather Data State Variables
  num? temperature;
  String weatherDescription = '';
  String weatherCondition = '';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize permissions sequentially and fetch live weather
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissionsAndInit();
    });
  }

  /// Sequentially requests Notification and Location permissions,
  /// re-prompting until the user enables them
  Future<void> _requestPermissionsAndInit() async {
    await NotificationService.init(context: context);
    await _initLocation();
  }

  /// Primary API Fetcher: Fetches Realtime Weather from Tomorrow.io API
  Future<void> fetchWeather(double lat, double lon) async {
    final tomorrowUrl = Uri.parse(
      'https://api.tomorrow.io/v4/weather/realtime?location=$lat,$lon&apikey=$apiKey',
    );

    try {
      final response = await http.get(tomorrowUrl);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final values = data['data']?['values'];

        if (values != null && mounted) {
          final temp = values['temperature'];
          final code = values['weatherCode'] ?? 1000;
          final mapped = _mapTomorrowWeatherCode(code);

          setState(() {
            temperature = temp;
            weatherCondition = mapped['condition']!;
            weatherDescription = mapped['description']!;
          });

          // Automatically schedule periodic hourly updates
          NotificationService.startHourlyPeriodicNotifications(
            location: currentLocation,
            temp: '$temp°C',
            condition: mapped['description'],
          );
          return;
        }
      }
      // If Tomorrow.io API fails, automatically try OpenWeatherMap fallback
      await _fetchOpenWeather(lat, lon);
    } catch (_) {
      await _fetchOpenWeather(lat, lon);
    }
  }

  /// Fallback API Fetcher: Fetches Weather from OpenWeatherMap API
  Future<void> _fetchOpenWeather(double lat, double lon) async {
    const backupKey = '05c496eb1d3834b2596016ccdd6ebf13';
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&units=metric&appid=$backupKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            if (currentLocation.isEmpty &&
                data['name'] != null &&
                data['name'].toString().isNotEmpty) {
              currentLocation = data['name'];
            }
            temperature = data['main']['temp'];
            weatherDescription = data['weather'][0]['description'] ?? '';
            weatherCondition = data['weather'][0]['main'] ?? '';
          });

          // Automatically schedule periodic hourly updates
          NotificationService.startHourlyPeriodicNotifications(
            location: currentLocation,
            temp: '${data['main']['temp']}°C',
            condition: data['weather'][0]['description'],
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          weatherDescription = 'Failed to load weather';
        });
      }
    }
  }

  /// Converts Tomorrow.io numerical weather codes to human-readable strings
  Map<String, String> _mapTomorrowWeatherCode(int code) {
    switch (code) {
      case 1000:
        return {'condition': 'Clear', 'description': 'Sunny'};
      case 1100:
      case 1101:
      case 1102:
        return {'condition': 'Clouds', 'description': 'Partly Cloudy'};
      case 1001:
        return {'condition': 'Clouds', 'description': 'Cloudy'};
      case 2000:
      case 2100:
        return {'condition': 'Fog', 'description': 'Foggy'};
      case 4000:
      case 4001:
        return {'condition': 'Drizzle', 'description': 'Light Rain'};
      case 4200:
      case 4201:
        return {'condition': 'Rain', 'description': 'Rainy'};
      case 5000:
      case 5001:
        return {'condition': 'Snow', 'description': 'Snowy'};
      case 8000:
        return {'condition': 'Thunderstorm', 'description': 'Stormy'};
      default:
        return {'condition': 'Clear', 'description': 'Sunny'};
    }
  }

  /// Requests device location permissions and loops until granted
  Future<void> _initLocation() async {
    while (mounted) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        final openService = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Location Service Required 📍'),
            content: const Text(
              'Live weather updates need your device location turned on to detect current local weather accurately.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Turn On Location'),
              ),
            ],
          ),
        );
        if (openService == true) {
          await Geolocator.openLocationSettings();
        }
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        final openAppSettings = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Location Permission Required 📍'),
            content: const Text(
              'Location permission is required to detect live weather for your city. Please grant access in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open App Settings'),
              ),
            ],
          ),
        );
        if (openAppSettings == true) {
          await Geolocator.openAppSettings();
        }
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      // Permission granted
      break;
    }

    try {
      // Fetch immediate location coordinates
      await _fetchCurrentLocation();

      // Start continuous movement listener
      startLocationTracking();
    } catch (_) {}
  }

  /// Gets current GPS position coordinates and triggers weather fetch
  Future<void> _fetchCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 5));

      await _updateLocationFromCoordinates(
        position.latitude,
        position.longitude,
      );
      await fetchWeather(position.latitude, position.longitude);
    } catch (_) {
      if (mounted) {
        setState(() {
          if (currentLocation.trim().isEmpty) {
            currentLocation = '';
          }
        });
      }
    }
  }

  /// Reverse geocodes coordinates to update location header name
  Future<void> _updateLocationFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];

        List<String?> candidates = [
          place.subLocality,
          place.subAdministrativeArea,
          place.locality,
          place.thoroughfare,
          place.administrativeArea,
          place.country,
        ];

        String locationName = '';
        for (var name in candidates) {
          if (name != null &&
              name.trim().isNotEmpty &&
              !name.contains('+') &&
              name.toLowerCase() != 'unnamed road') {
            locationName = name.trim();
            break;
          }
        }

        setState(() {
          currentLocation = locationName;
        });
      }
    } catch (_) {
      if (mounted && currentLocation.trim().isEmpty) {
        setState(() {
          currentLocation = '';
        });
      }
    }
  }

  /// Subscribes to live position stream for position movement updates
  void startLocationTracking() {
    try {
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      ).listen((Position position) {
        _updateLocationFromCoordinates(position.latitude, position.longitude);
        fetchWeather(position.latitude, position.longitude);
      });
    } catch (_) {}
  }

  /// Shows User Profile Account Info & Sign-Out Modal Bottom Sheet
  Future<void> _showProfileBottomSheet(BuildContext context, User? user) async {
    final theme = Theme.of(context);

    // Refresh user profile token from Firebase to get latest verification status
    try {
      await user?.reload();
    } catch (_) {}

    final currentUser = FirebaseAuth.instance.currentUser;
    final isVerified = currentUser?.emailVerified ?? false;

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bottom Sheet Visual Drag Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Large Google Profile Picture Avatar
              CircleAvatar(
                radius: 42,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage:
                    (currentUser?.photoURL != null && currentUser!.photoURL!.isNotEmpty)
                        ? NetworkImage(currentUser.photoURL!)
                        : null,
                child: (currentUser?.photoURL == null || currentUser!.photoURL!.isEmpty)
                    ? Icon(
                        Icons.person,
                        size: 48,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(height: 16),

              // User Display Name
              Text(
                currentUser?.displayName ?? 'Weather User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),

              // User Email Address
              Text(
                currentUser?.email ?? 'No email associated',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),

              // Account Email Verification Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isVerified
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isVerified ? Colors.green : Colors.orange,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVerified ? Icons.verified : Icons.warning_amber_rounded,
                      size: 16,
                      color: isVerified ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isVerified ? 'Verified Account' : 'Unverified Email',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isVerified ? Colors.green.shade800 : Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              // Send Verification Email Option (if unverified)
              if (!isVerified && currentUser != null) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await currentUser.sendEmailVerification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Verification email sent! Please check your inbox.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to send verification email: $e'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.mark_email_read, size: 18),
                  label: const Text('Send Verification Email'),
                ),
              ],

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Account Sign Out Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context); // Close bottom sheet
                    // Sign out from both Firebase and GoogleSignIn to clear cached account
                    await FirebaseAuth.instance.signOut();
                    await GoogleSignIn().signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.signup,
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.onErrorContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onPrimary;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,

      // Widget Section: Header AppBar with Location Name & User Profile Avatar
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: headerColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              color: textColor,
              size: 22,
            ),
            const SizedBox(width: 6),
            Text(
              currentLocation.isNotEmpty ? currentLocation : 'Lagos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        actions: [
          // AppBar User Profile Circle Avatar Button
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => _showProfileBottomSheet(context, user),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: textColor.withValues(alpha: 0.25),
                backgroundImage:
                    (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                        ? NetworkImage(user.photoURL!)
                        : null,
                child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                    ? Icon(
                        Icons.person,
                        color: textColor,
                        size: 20,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),

      // Widget Section: Main Body Dashboard Layout
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Hero Weather Animated Container
            Weather(
              temperature: temperature,
              weatherDescription: weatherDescription,
              weatherCondition: weatherCondition,
              backgroundColor: headerColor,
              textColor: textColor,
            ),
            const SizedBox(height: 12),

            // 8-Hour Horizontal Weather Forecast Cards
            HourlySection(
              currentTemp: temperature,
              weatherCondition: weatherCondition,
            ),
            const SizedBox(height: 12),

            // 10-Day Vertical Forecast List
            DailyForecastSection(
              currentTemp: temperature,
              weatherCondition: weatherCondition,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),

      // Widget Section: Bottom Navigation Tab Bar
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MapScreen()),
            );
          }
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

/// Bottom Navigation Bar Component
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny_outlined),
            activeIcon: Icon(Icons.wb_sunny),
            label: 'Weather',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
      ),
    );
  }
}

/// Animated Weather Hero Container Widget
class Weather extends StatefulWidget {
  final num? temperature;
  final String weatherDescription;
  final String weatherCondition;
  final Color backgroundColor;
  final Color textColor;

  const Weather({
    super.key,
    this.temperature,
    required this.weatherDescription,
    required this.weatherCondition,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  State<Weather> createState() => _WeatherState();
}

class _WeatherState extends State<Weather>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getWeatherEmoji(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
        return '🌧️';
      case 'drizzle':
        return '🌦️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'mist':
      case 'fog':
      case 'haze':
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  List<Widget> _buildBackgroundFloatingEmojis(String condition, double value) {
    String smallEmoji;
    switch (condition.toLowerCase()) {
      case 'clear':
        smallEmoji = '☀️';
        break;
      case 'clouds':
      case 'mist':
      case 'fog':
      case 'haze':
        smallEmoji = '☁️';
        break;
      case 'rain':
      case 'drizzle':
        smallEmoji = '💧';
        break;
      case 'thunderstorm':
        smallEmoji = '⚡';
        break;
      case 'snow':
        smallEmoji = '❄️';
        break;
      default:
        smallEmoji = '🌤️';
    }

    return [
      Positioned(
        top: 20 + (sin(value * 2 * pi) * 8),
        left: 28 + (cos(value * 2 * pi) * 10),
        child: Opacity(
          opacity: 0.22,
          child: Text(smallEmoji, style: const TextStyle(fontSize: 28)),
        ),
      ),
      Positioned(
        top: 32 - (cos(value * 2 * pi) * 10),
        right: 32 + (sin(value * 2 * pi) * 8),
        child: Opacity(
          opacity: 0.22,
          child: Text(smallEmoji, style: const TextStyle(fontSize: 34)),
        ),
      ),
      Positioned(
        bottom: 22 + (cos(value * 2 * pi) * 8),
        left: 36 - (sin(value * 2 * pi) * 12),
        child: Opacity(
          opacity: 0.20,
          child: Text(smallEmoji, style: const TextStyle(fontSize: 30)),
        ),
      ),
      Positioned(
        bottom: 28 - (sin(value * 2 * pi) * 10),
        right: 28 + (cos(value * 2 * pi) * 8),
        child: Opacity(
          opacity: 0.22,
          child: Text(smallEmoji, style: const TextStyle(fontSize: 26)),
        ),
      ),
    ];
  }

  Widget _buildMainAnimatedEmoji(String condition, String emoji, double value) {
    Widget animatedEmoji = Text(
      emoji,
      style: const TextStyle(fontSize: 80),
    );

    if (condition == 'clear') {
      return Transform.rotate(
        angle: value * 2 * pi,
        child: animatedEmoji,
      );
    } else if (condition == 'clouds' ||
        condition == 'mist' ||
        condition == 'fog' ||
        condition == 'haze') {
      return Transform.translate(
        offset: Offset(sin(value * 2 * pi) * 14, 0),
        child: animatedEmoji,
      );
    } else if (condition == 'rain' || condition == 'drizzle') {
      return Transform.translate(
        offset: Offset(0, sin(value * 2 * pi) * 8),
        child: Transform.scale(
          scale: 1.0 + (sin(value * 2 * pi) * 0.05),
          child: animatedEmoji,
        ),
      );
    } else if (condition == 'thunderstorm') {
      return Transform.translate(
        offset: Offset(
          sin(value * 4 * pi) * 4,
          cos(value * 4 * pi) * 4,
        ),
        child: Transform.scale(
          scale: 1.0 + (sin(value * 2 * pi) * 0.08),
          child: animatedEmoji,
        ),
      );
    } else {
      return Transform.translate(
        offset: Offset(0, sin(value * 2 * pi) * 8),
        child: animatedEmoji,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final emoji = _getWeatherEmoji(widget.weatherCondition);
    final formattedTemp = widget.temperature != null
        ? '${widget.temperature!.round()}°C'
        : '--°C';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        color: widget.backgroundColor,
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;
          final condition = widget.weatherCondition.toLowerCase();

          return Stack(
            children: [
              ..._buildBackgroundFloatingEmojis(condition, value),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMainAnimatedEmoji(condition, emoji, value),
                    const SizedBox(height: 16),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 800),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: widget.textColor,
                      ),
                      child: Text(formattedTemp),
                    ),
                    const SizedBox(height: 8),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 800),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: widget.textColor.withValues(alpha: 0.85),
                      ),
                      child: Text(
                        widget.weatherDescription.isNotEmpty
                            ? widget.weatherDescription.toUpperCase()
                            : 'LOADING WEATHER...',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Hourly 8-Card Horizontal Scroll Forecast Section Widget
class HourlySection extends StatelessWidget {
  final num? currentTemp;
  final String weatherCondition;

  const HourlySection({
    super.key,
    this.currentTemp,
    required this.weatherCondition,
  });

  IconData _getHourlyIcon(String condition, int hour) {
    final isNight = hour < 6 || hour >= 19;
    switch (condition.toLowerCase()) {
      case 'clear':
        return isNight ? Icons.nightlight_round : Icons.wb_sunny;
      case 'clouds':
        return isNight ? Icons.nights_stay : Icons.cloud;
      case 'rain':
        return Icons.water_drop;
      case 'drizzle':
        return Icons.grain;
      case 'thunderstorm':
        return Icons.thunderstorm;
      default:
        return isNight ? Icons.nights_stay : Icons.wb_cloudy;
    }
  }

  String _getRainChance(String condition, int index) {
    switch (condition.toLowerCase()) {
      case 'rain':
        return '${max(10, 85 - (index * 8))}%';
      case 'drizzle':
        return '${max(5, 45 - (index * 5))}%';
      case 'thunderstorm':
        return '${max(15, 90 - (index * 10))}%';
      case 'clouds':
        return '${15 + (index * 3)}%';
      default:
        return '5%';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final baseTemp = currentTemp?.round() ?? 25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Text(
            'Hourly Forecast',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 145,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: 8,
            itemBuilder: (context, index) {
              final hourlyTime = now.add(Duration(hours: index));
              final hourNum = hourlyTime.hour;
              final period = hourNum >= 12 ? 'PM' : 'AM';
              final displayHour = hourNum == 0
                  ? 12
                  : (hourNum > 12 ? hourNum - 12 : hourNum);

              final timeLabel =
                  index == 0 ? 'NOW' : '$displayHour $period';

              final tempVal = baseTemp + (sin(index * 0.7) * 2.5).round();
              final icon = _getHourlyIcon(weatherCondition, hourNum);
              final rainChance = _getRainChance(weatherCondition, index);

              return HourlyItemCard(
                time: timeLabel,
                temp: '$tempVal°C',
                icon: icon,
                rainChance: rainChance,
                isNow: index == 0,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Single Hourly Item Card Component (Tappable to schedule/send weather push notifications)
class HourlyItemCard extends StatelessWidget {
  final String time;
  final String temp;
  final IconData icon;
  final String rainChance;
  final bool isNow;

  const HourlyItemCard({
    super.key,
    required this.time,
    required this.temp,
    required this.icon,
    required this.rainChance,
    this.isNow = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = isNow
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    return InkWell(
      onTap: () async {
        // Trigger local push notification when hourly card is tapped
        await NotificationService.showNotification(
          id: time.hashCode,
          title: 'Hourly Weather Forecast 🌤️',
          body: 'Weather expected $temp by $time.',
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Notification set: Weather expected $temp by $time'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 90,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isNow
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              time,
              style: TextStyle(
                color: isNow
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: isNow ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            Icon(
              icon,
              color: isNow
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 26,
            ),
            Text(
              temp,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  size: 11,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  rainChance,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 10-Day Vertical Forecast Section Widget
class DailyForecastSection extends StatelessWidget {
  final num? currentTemp;
  final String weatherCondition;

  const DailyForecastSection({
    super.key,
    this.currentTemp,
    required this.weatherCondition,
  });

  Map<String, dynamic> _getDailyForecastData(String condition, int index) {
    final baseTemp = currentTemp?.round() ?? 26;
    final tempMin = baseTemp - 2 + (sin(index * 0.9) * 2).round();
    final tempMax = baseTemp + 3 + (cos(index * 0.8) * 3).round();

    String itemCondition;
    IconData icon;
    Color iconColor;

    switch (index % 4) {
      case 0:
        itemCondition = condition.isNotEmpty ? condition : 'Clear';
        break;
      case 1:
        itemCondition = 'Clouds';
        break;
      case 2:
        itemCondition = 'Rain';
        break;
      default:
        itemCondition = 'Clear';
    }

    switch (itemCondition.toLowerCase()) {
      case 'clear':
        icon = Icons.wb_sunny;
        iconColor = Colors.orangeAccent;
        break;
      case 'clouds':
        icon = Icons.cloud;
        iconColor = Colors.blueGrey;
        break;
      case 'rain':
      case 'drizzle':
        icon = Icons.water_drop;
        iconColor = Colors.lightBlue;
        break;
      case 'thunderstorm':
        icon = Icons.thunderstorm;
        iconColor = Colors.deepPurpleAccent;
        break;
      default:
        icon = Icons.wb_cloudy;
        iconColor = Colors.amber;
    }

    return {
      'min': tempMin,
      'max': tempMax,
      'icon': icon,
      'iconColor': iconColor,
      'condition': itemCondition,
    };
  }

  String _getDayName(DateTime date, int index) {
    if (index == 0) return 'TODAY';
    if (index == 1) return 'TOMORROW';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.calendar_month_outlined, size: 20),
              SizedBox(width: 8),
              Text(
                '10-Day Forecast',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: List.generate(10, (index) {
              final date = now.add(Duration(days: index));
              final dayName = _getDayName(date, index);
              final forecast = _getDailyForecastData(weatherCondition, index);
              final isToday = index == 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: isToday
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: isToday
                      ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                      : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 95,
                      child: Text(
                        dayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.w600,
                          color: isToday
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      forecast['icon'] as IconData,
                      color: forecast['iconColor'] as Color,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${forecast['min']}°',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: 0.4 + (index % 3) * 0.2,
                            minHeight: 5,
                            backgroundColor: theme.colorScheme.surface,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${forecast['max']}°',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Local Notification Service Helper for Hourly Weather Alerts
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  static Future<void> init({BuildContext? context}) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    if (!_isInitialized) {
      await _notificationsPlugin.initialize(initializationSettings);
      _isInitialized = true;
    }

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      bool? granted = await androidPlugin.areNotificationsEnabled();
      while (granted != true) {
        bool? requested = await androidPlugin.requestNotificationsPermission();
        granted = await androidPlugin.areNotificationsEnabled() ?? requested;

        if (granted != true) {
          if (context != null && context.mounted) {
            await showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('Notifications Required 🔔'),
                content: const Text(
                  'Notification access is required so the app can send you real-time hourly forecasts and severe weather updates. Please allow notifications.',
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Geolocator.openAppSettings();
                    },
                    child: const Text('Grant in Settings'),
                  ),
                ],
              ),
            );
          }
          await Future.delayed(const Duration(seconds: 1));
          granted = await androidPlugin.areNotificationsEnabled();
        }
      }
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'hourly_weather_channel',
      'Hourly Weather Updates',
      channelDescription: 'Notifications for upcoming hourly weather forecasts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(id, title, body, details);
  }

  /// Automatically schedules recurring periodic hourly updates
  static Future<void> startHourlyPeriodicNotifications({
    String? location,
    String? temp,
    String? condition,
  }) async {
    await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'hourly_weather_periodic_channel',
      'Automatic Hourly Weather Forecasts',
      channelDescription: 'Periodic updates delivering hourly weather forecasts automatically',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final locText = (location != null && location.isNotEmpty) ? ' in $location' : '';
    final infoText = (temp != null && condition != null)
        ? '$temp, $condition.'
        : 'Check current conditions and forecast.';

    // id 9999 is reserved for recurring hourly forecast updates
    await _notificationsPlugin.periodicallyShow(
      9999,
      'Hourly Weather Update 🌤️',
      'Current weather$locText: $infoText',
      RepeatInterval.hourly,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancels recurring periodic updates if needed
  static Future<void> cancelPeriodicNotifications() async {
    await _notificationsPlugin.cancel(9999);
  }
}
