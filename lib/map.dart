// ============================================================================
// FILE: lib/map.dart
// PURPOSE: Interactive Map & Weather Search Screen
// 
// NARRATION / ARCHITECTURE:
// - Allows searching for any location worldwide using a search bar.
// - Geocodes user text input into coordinates (`locationFromAddress`).
// - Shifts OpenStreetMap tile layer (`FlutterMap`) and moves map pin marker.
// - Supports direct map taps to pick any location point on the globe.
// - Fetches real-time weather from Tomorrow.io API (with OpenWeather fallback) 
//   and displays results inside a floating `AnimatedMapWeatherCard`.
// ============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'weather.dart';

/// Interactive Map Screen Widget
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  /// MapController managing map panning, zooming, and marker repositioning
  final MapController _mapController = MapController();

  /// TextEditingController handling search query field input
  final TextEditingController _searchController = TextEditingController();

  /// Default starting coordinates (Lagos, Nigeria)
  LatLng _selectedLatLng = const LatLng(6.5244, 3.3792);
  String _selectedLocationName = 'Lagos, Nigeria';

  /// Weather State Variables
  bool _isLoadingWeather = false;
  num? _temperature;
  String _weatherCondition = '';
  String _weatherDescription = '';
  num? _humidity;
  num? _windSpeed;
  bool _hasError = false;

  int _currentIndex = 1;

  /// Tomorrow.io API Key
  final String _apiKey = 'Ovmvkn44lgJhXyGfqQoyngeKr7T1bmEl';

  @override
  void initState() {
    super.initState();
    // Fetch initial device position or fallback position weather on load
    _initInitialLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Tries to acquire current GPS location on screen launch
  Future<void> _initInitialLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
            ),
          ).timeout(const Duration(seconds: 4));

          final latLng = LatLng(position.latitude, position.longitude);
          _selectedLatLng = latLng;
          await _reverseGeocode(position.latitude, position.longitude);
        }
      }
    } catch (_) {
      // Fallback location already set
    } finally {
      _fetchWeatherForLocation(
          _selectedLatLng.latitude, _selectedLatLng.longitude);
    }
  }

  /// Converts coordinates into human-readable address names
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        List<String?> candidates = [
          place.subLocality,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.country,
        ];

        String name = candidates.firstWhere(
          (element) => element != null && element.trim().isNotEmpty,
          orElse: () => null,
        ) ?? 'Selected Location';

        String country = place.country ?? '';
        String fullName = country.isNotEmpty && !name.contains(country)
            ? '$name, $country'
            : name;

        setState(() {
          _selectedLocationName = fullName;
          _searchController.text = fullName;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedLocationName =
              '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}';
        });
      }
    }
  }

  /// Forward Geocoding: Converts search text query to LatLng and updates map
  Future<void> _searchAndMove(String address) async {
    final query = address.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoadingWeather = true;
      _hasError = false;
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final targetLatLng = LatLng(loc.latitude, loc.longitude);

        setState(() {
          _selectedLatLng = targetLatLng;
          _selectedLocationName = query;
        });

        _mapController.move(targetLatLng, 13.0);

        await _reverseGeocode(loc.latitude, loc.longitude);
        await _fetchWeatherForLocation(loc.latitude, loc.longitude);
      } else {
        _showSnackbar('Location not found. Please try another search.');
        setState(() {
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      _showSnackbar('Could not find location "$query".');
      setState(() {
        _isLoadingWeather = false;
        _hasError = true;
      });
    }
  }

  /// Map Tap Handler: Updates pin to tapped point and fetches weather
  Future<void> _onMapTapped(LatLng point) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedLatLng = point;
      _isLoadingWeather = true;
      _hasError = false;
    });

    _mapController.move(point, _mapController.camera.zoom);

    await _reverseGeocode(point.latitude, point.longitude);
    await _fetchWeatherForLocation(point.latitude, point.longitude);
  }

  /// Center Map on User's Current GPS Location
  Future<void> _locateUser() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackbar('Please enable location services.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackbar('Location permissions were denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackbar('Location permissions are permanently denied.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 5));

      final userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLatLng = userLatLng;
      });

      _mapController.move(userLatLng, 14.0);
      await _reverseGeocode(position.latitude, position.longitude);
      await _fetchWeatherForLocation(position.latitude, position.longitude);
    } catch (e) {
      _showSnackbar('Failed to acquire current location.');
    }
  }

  /// Primary API Weather Fetcher for selected LatLng
  Future<void> _fetchWeatherForLocation(double lat, double lon) async {
    setState(() {
      _isLoadingWeather = true;
      _hasError = false;
    });

    final tomorrowUrl = Uri.parse(
      'https://api.tomorrow.io/v4/weather/realtime?location=$lat,$lon&apikey=$_apiKey',
    );

    try {
      final response = await http.get(tomorrowUrl);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final values = data['data']?['values'];

        if (values != null && mounted) {
          final temp = values['temperature'];
          final humidity = values['humidity'];
          final wind = values['windSpeed'];
          final code = values['weatherCode'] ?? 1000;
          final mapped = _mapTomorrowWeatherCode(code);

          setState(() {
            _temperature = temp;
            _humidity = humidity;
            _windSpeed = wind;
            _weatherCondition = mapped['condition']!;
            _weatherDescription = mapped['description']!;
            _isLoadingWeather = false;
          });
          return;
        }
      }
      // Fallback to OpenWeatherMap API
      await _fetchOpenWeather(lat, lon);
    } catch (_) {
      await _fetchOpenWeather(lat, lon);
    }
  }

  /// Backup API Weather Fetcher (OpenWeatherMap)
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
            _temperature = data['main']?['temp'];
            _humidity = data['main']?['humidity'];
            _windSpeed = data['wind']?['speed'];
            _weatherDescription = data['weather']?[0]?['description'] ?? '';
            _weatherCondition = data['weather']?[0]?['main'] ?? '';
            _isLoadingWeather = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingWeather = false;
            _hasError = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
          _hasError = true;
        });
      }
    }
  }

  /// Tomorrow.io weather code mapper
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

  /// Helper displaying floating user SnackBar feedback
  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,

      // Widget Section: Header AppBar
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
              Icons.map_outlined,
              color: textColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Map Weather Search',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
              ),
            ),
          ],
        ),
      ),

      // Widget Section: Main Body with Search Bar & Stack Map
      body: SafeArea(
        child: Column(
          children: [
            // Widget: Top Location Search Bar Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Search(
                controller: _searchController,
                onSubmitted: _searchAndMove,
                onLocateTap: _locateUser,
              ),
            ),

            // Widget Section: Stack Layering Map and Animated Weather Card
            Expanded(
              child: Stack(
                children: [
                  // Layer 1 (Bottom): OpenStreetMap Tile Engine
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLatLng,
                      initialZoom: 12.0,
                      onTap: (_, point) => _onMapTapped(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.weather_app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLatLng,
                            width: 50,
                            height: 50,
                            child: Icon(
                              Icons.location_pin,
                              color: theme.colorScheme.primary,
                              size: 46,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Layer 2 (Top Right): Floating Locate FAB
                  Positioned(
                    right: 16,
                    top: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'map_locate_fab',
                      onPressed: _locateUser,
                      backgroundColor: theme.colorScheme.surface,
                      foregroundColor: theme.colorScheme.primary,
                      elevation: 4,
                      child: const Icon(Icons.my_location),
                    ),
                  ),

                  // Layer 3 (Bottom Overlay): Animated Floating Weather Card
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: AnimatedMapWeatherCard(
                      locationName: _selectedLocationName,
                      temperature: _temperature,
                      weatherCondition: _weatherCondition,
                      weatherDescription: _weatherDescription,
                      humidity: _humidity,
                      windSpeed: _windSpeed,
                      isLoading: _isLoadingWeather,
                      hasError: _hasError,
                      onRefresh: () => _fetchWeatherForLocation(
                        _selectedLatLng.latitude,
                        _selectedLatLng.longitude,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Widget Section: Bottom Navigation Tab Bar
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Home()),
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

/// Search Bar Input Component
class Search extends StatelessWidget {
  final TextEditingController? controller;
  final Function(String)? onSubmitted;
  final VoidCallback? onLocateTap;

  const Search({
    super.key,
    this.controller,
    this.onSubmitted,
    this.onLocateTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontSize: 15,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'Search city or location...',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          prefixIcon: IconButton(
            icon: Icon(
              Icons.search,
              color: theme.colorScheme.primary,
            ),
            onPressed: () {
              if (controller != null && controller!.text.isNotEmpty) {
                onSubmitted?.call(controller!.text);
              }
            },
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller != null && controller!.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    controller!.clear();
                  },
                ),
              IconButton(
                icon: Icon(
                  Icons.my_location,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                onPressed: onLocateTap,
                tooltip: 'My Location',
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

/// Stateful Weather Card Widget featuring Floating Animation Loop
class AnimatedMapWeatherCard extends StatefulWidget {
  final String locationName;
  final num? temperature;
  final String weatherCondition;
  final String weatherDescription;
  final num? humidity;
  final num? windSpeed;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRefresh;

  const AnimatedMapWeatherCard({
    super.key,
    required this.locationName,
    this.temperature,
    required this.weatherCondition,
    required this.weatherDescription,
    this.humidity,
    this.windSpeed,
    required this.isLoading,
    required this.hasError,
    required this.onRefresh,
  });

  @override
  State<AnimatedMapWeatherCard> createState() => _AnimatedMapWeatherCardState();
}

class _AnimatedMapWeatherCardState extends State<AnimatedMapWeatherCard>
    with SingleTickerProviderStateMixin {
  /// AnimationController driving the floating translation effect
  late final AnimationController _animController;
  late final Animation<double> _floatingAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _floatingAnim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Maps condition string to matching emoji icon
  String _getWeatherEmoji(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return '☀️';
      case 'clouds':
        return '☁️';
      case 'rain':
      case 'drizzle':
        return '🌧️';
      case 'thunderstorm':
        return '⛈️';
      case 'snow':
        return '❄️';
      case 'fog':
      case 'mist':
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.colorScheme.primaryContainer;
    final onCardColor = theme.colorScheme.onPrimaryContainer;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: widget.isLoading
          ? SizedBox(
              height: 100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Fetching weather for ${widget.locationName}...',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: onCardColor,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : widget.hasError
              ? Row(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 36,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.locationName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: onCardColor,
                            ),
                          ),
                          Text(
                            'Could not fetch weather data.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: widget.onRefresh,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Location Title & Refresh Action Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.locationName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: onCardColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: widget.onRefresh,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.refresh,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Row 2: Animated Floating Emoji, Temperature, and Detail Chips
                    Row(
                      children: [
                        // Animated Weather Emoji Vector Icon
                        AnimatedBuilder(
                          animation: _floatingAnim,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _floatingAnim.value),
                              child: child,
                            );
                          },
                          child: Text(
                            _getWeatherEmoji(widget.weatherCondition),
                            style: const TextStyle(fontSize: 48),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Temperature & Description Texts
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.temperature != null
                                    ? '${widget.temperature!.round()}°C'
                                    : '--°C',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: onCardColor,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.weatherDescription.isNotEmpty
                                    ? widget.weatherDescription.toUpperCase()
                                    : widget.weatherCondition.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Detail Chips (Humidity & Wind)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (widget.humidity != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface
                                      .withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.water_drop,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.humidity!.round()}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 6),
                            if (widget.windSpeed != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface
                                      .withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.air,
                                      size: 14,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${widget.windSpeed!.round()} m/s',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
