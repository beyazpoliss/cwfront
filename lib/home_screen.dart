import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:cwfront/login_screen.dart';
import 'package:cwfront/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'verification_screen.dart';
import 'app_localizations.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'worker_page.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:location/location.dart' as loc;



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _timeString;
  Timer? _timeTimer;
  Timer? _workerDataTimer;
  LocationData? _currentLocation;
  final Location _locationService = Location();
  final ImagePicker _picker = ImagePicker();

  String _currentLanguage = "en";

  // Worker data
  String _workerName = '';
  String _workStatus = '';
  String _workDuration = '';
  String _breakDuration = '';

  @override
  void initState() {
    super.initState();
    _timeString = _formatCurrentTime();
    _timeTimer =
        Timer.periodic(const Duration(minutes: 1), (Timer t) => _updateTime());
    _workerDataTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) =>
        _fetchWorkerData()); // Update worker data every 5 seconds
    _requestLocationPermission();
    Timer.periodic(const Duration(minutes
        : 1), (Timer t) => _sendGpsVerification());
  }

  Future<void> _sendGpsVerification() async {
    try {
      // Get the current GPS location

      print("sended 1");
      final gpsLocation = await _getCurrentGpsLocation();
      print(gpsLocation);
      if (gpsLocation == null) {
        print('Unable to fetch GPS location');
        return;
      }

      // Prepare the request body
      final requestBody = {
        'username': '$_workerName',
        // Replace with actual username
        'gpsLocation': jsonEncode(gpsLocation),
        // Ensure the location is in string format
      };

      print("sended "
          "2");

      // Send the request
      final response = await http.post(
        Uri.parse('${StorageService.url}/gps-verification'),
        headers: {
          'Authorization': 'Bearer ${await StorageService.read("jwt_token")}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print("sended 3");

      if (response.statusCode == 200) {
        // Handle successful response
        print("sended 4");
        print('GPS verification successful: ${response.body}');
      } else {
        // Handle errors
        print(
            'Failed to verify GPS: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      print('Error sending GPS verification request: $error');
    }
  }

// Method to get current GPS location
// Your code...

// Method to get current GPS location
  Future<Map<String, double>?> _getCurrentGpsLocation() async {
    try {
      // Check for location permission using geolocator
      geo.LocationPermission permission = await geo.Geolocator
          .checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          return null; // Permission denied
        }
      }

      // Get current position using geolocator
      geo.Position position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high);

      // Return latitude and longitude
      return {
        'lat': position.latitude,
        'lon': position.longitude,
      };
    } catch (e) {
      print('Error getting GPS location: $e');
      return null; // Handle error
    }
  }


  @override
  void dispose() {
    _timeTimer?.cancel();
    _workerDataTimer
        ?.cancel(); // Cancel worker data timer when the widget is disposed
    super.dispose();
  }

  void _handleLunchButtonPressed() async {
    if (_workStatus == 'Clock Out' ||
        _workStatus == AppLocalizations.of(context)?.translate('clock_out')) {
      // Clocked out, show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            AppLocalizations.of(context)?.translate('error_must_clock_in') ??
                'You must be clocked in to start lunch')),
      );
      return;
    }

    try {
      final token = await StorageService.read("jwt_token");
      final username = await StorageService.read("username");

      if (username == null) {
        print('Username not found');
        return;
      }

      final response = await http.post(
        Uri.parse('${StorageService.url}/lunch-toggle'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'username': username}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _workStatus = data['status'] == 'on lunch'
              ? AppLocalizations.of(context)?.translate('lunch') ?? 'Lunch'
              : AppLocalizations.of(context)?.translate('clock_in') ??
              'Clock In';
          _breakDuration = '${data['totalLunchHours']} hours';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      } else {
        print('Failed to toggle lunch status: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.translate(
              'error_failed_toggle_lunch') ?? 'Failed to toggle lunch status')),
        );
      }
    } catch (e) {
      print('Error toggling lunch status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.translate(
            'error_failed_toggle_lunch') ?? 'Failed to toggle lunch status')),
      );
    }
  }

  Future<void> _fetchWorkerData() async {
    try {
      final token = await StorageService.read("jwt_token");
      final username = await StorageService.read("username");

      if (username == null) {
        print('Username not found');
        return;
      }

      print('Fetching data from: ${StorageService
          .url}/worker?username=$username');
      print('Token: $token');

      final response = await http.get(
        Uri.parse('${StorageService.url}/worker?username=$username'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (!mounted) return;

        setState(() {
          _workerName = data['username'] ?? '';
          final dailyLogs = (data['dailyLogs'] as List?) ?? [];

          if (dailyLogs.isNotEmpty) {
            final lastLog = dailyLogs.last;
            final int status = lastLog['status'] ?? 0;

            _workStatus = status == 2
                ? AppLocalizations.of(context)?.translate('lunch') ?? 'Lunch'
                : status == 1
                ? AppLocalizations.of(context)?.translate('clock_in') ??
                'Clock In'
                : AppLocalizations.of(context)?.translate('clock_out') ??
                'Clock Out';

            // Get the work duration in seconds
            final workDurationInSeconds = lastLog['workDurationInSeconds'] ?? 0;

            print(workDurationInSeconds);
            // Convert work duration to hours and minutes
            final workDurationInHours = (workDurationInSeconds / 3600).floor();
            final workDurationInMinutes = ((workDurationInSeconds % 3600) / 60)
                .floor();

            _workDuration = workDurationInHours >= 1
                ? '${workDurationInHours}h ${workDurationInMinutes}m'
                : '${workDurationInMinutes}m';

            // Calculate lunch break duration
            final lunchBreaks = (lastLog['lunchBreaks'] as List?) ?? [];
            var lunchDurationInSeconds = 0;

            for (var break_ in lunchBreaks) {
              final startTime = DateTime.parse(break_['lunchStartTime']);

              // Check if lunchEndTime exists and is not null or empty
              if (break_['lunchEndTime'] != null &&
                  break_['lunchEndTime'].isNotEmpty) {
                final endTime = DateTime.parse(break_['lunchEndTime']);
                if (endTime.isAfter(startTime)) {
                  lunchDurationInSeconds += endTime
                      .difference(startTime)
                      .inSeconds;
                }
              } else {
                // Handle the case where lunchEndTime is missing
                print(
                    'Warning: lunchEndTime is missing for a lunch break starting at $startTime.');
              }
            }


            // Convert lunch duration to hours and minutes
            final lunchDurationInHours = (lunchDurationInSeconds / 3600)
                .floor();
            final lunchDurationInMinutes = ((lunchDurationInSeconds % 3600) /
                60).floor();

            // Set break duration
            _breakDuration = lunchDurationInHours >= 1
                ? '${lunchDurationInHours}h ${lunchDurationInMinutes}m'
                : '${lunchDurationInMinutes}m';

            print('Work Duration: $_workDuration');
            print('Break Duration: $_breakDuration');
          } else {
            _workStatus =
                AppLocalizations.of(context)?.translate('clock_out') ??
                    'Clock Out';
            _workDuration = '0m';
            _breakDuration = '0m';
          }
        });
      } else {
        print('Failed to fetch worker data: ${response.statusCode} - ${response
            .body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.translate(
                  'error_fetching_data') ?? 'Error fetching worker data'),
            ),
          );
        }
      }
    } catch (e, stacktrace) {
      print('Error fetching worker data: $e');
      print(stacktrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.translate(
                'error_fetching_data') ?? 'Error fetching worker data'),
          ),
        );
      }
    }
  }


  void _updateTime() {
    setState(() {
      _timeString = _formatCurrentTime();
    });
  }

  String _formatCurrentTime() {
    final DateTime now = DateTime.now();
    return DateFormat('hh:mm a').format(now);
  }

  Future<void> _requestLocationPermission() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await _locationService.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _locationService.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await _locationService.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _locationService.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _currentLocation = await _locationService.getLocation();
  }

  Future<void> checkAdminAndNavigate(BuildContext context) async {
    try {
      final String? token = await StorageService.read("jwt_token");

      final response = await http.get(
        Uri.parse('${StorageService.url}/check-admin'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['isAdmin'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminHomePage()),
          );
        }
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }
  }

// ... (previous imports remain the same)

// ... (previous imports remain the same)


  void _navigateToVerificationScreen(bool isClockIn) {
    // Check if trying to clock in when already clocked in
    if (isClockIn &&
        _workStatus == AppLocalizations.of(context)?.translate('clock_in')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)?.translate(
                  'error_already_clocked_in') ??
                  'You are already clocked in.'
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if trying to clock in while on lunch
    if (isClockIn &&
        _workStatus == AppLocalizations.of(context)?.translate('lunch')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)?.translate(
                  'error_cant_clock_in_during_lunch') ??
                  'You cannot clock in while on lunch break. Please end your lunch break first.'
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if trying to clock out while on lunch
    if (!isClockIn &&
        _workStatus == AppLocalizations.of(context)?.translate('lunch')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)?.translate(
                  'error_cant_clock_out_during_lunch') ??
                  'You cannot clock out while on lunch break. Please end your lunch break first.'
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationScreen(isClockIn: isClockIn),
      ),
    );
  }

// ... (rest of the code remains the same)


// HomeScreen sınıfındaki _handleLanguageChange metodunu güncelle
  void _handleLanguageChange(String languageCode) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    localeProvider.setLocale(Locale(languageCode));
    setState(() {
      _currentLanguage = languageCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.7),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header with menu and admin buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => checkAdminAndNavigate(context),
                        child: const Icon(
                            Icons.security, size: 30, color: Colors.white),
                      ),
                      const Text(
                        'CW',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(
                            Icons.menu, size: 30, color: Colors.white),
                        onSelected: _handleLanguageChange,
                        itemBuilder: (BuildContext context) =>
                        [
                          PopupMenuItem<String>(
                            value: 'en',
                            child: Row(
                              children: [
                                const Text('🇺🇸 '),
                                const SizedBox(width: 8),
                                Text(localizations!.translate('english')),
                                if (_currentLanguage == 'en')
                                  const Icon(Icons.check, size: 20),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'es',
                            child: Row(
                              children: [
                                const Text('🇪🇸 '),
                                const SizedBox(width: 8),
                                Text(localizations.translate('spanish')),
                                if (_currentLanguage == 'es')
                                  const Icon(Icons.check, size: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Worker Info Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${localizations?.translate('name')}: $_workerName',
                          style: const TextStyle(fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${localizations?.translate('status')}: $_workStatus',
                          style: const TextStyle(fontSize: 16, color: Colors
                              .white),
                        ),
                        Text(
                          '${localizations?.translate(
                              'work_duration')}: $_workDuration',
                          style: const TextStyle(fontSize: 16, color: Colors
                              .white),
                        ),
                        Text(
                          '${localizations?.translate(
                              'break_duration')}: $_breakDuration',
                          style: const TextStyle(fontSize: 16, color: Colors
                              .white),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action Buttons
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ActionButton(
                          text: localizations!.translate('clock_in'),
                          color: const Color(0xFF8B7355),
                          icon: Icons.camera_alt,
                          onPressed: () => _navigateToVerificationScreen(true),
                        ),
                        const SizedBox(height: 16),
                        ActionButton(
                          text: localizations.translate('lunch'),
                          color: Colors.green,
                          icon: Icons.restaurant,
                          onPressed: _handleLunchButtonPressed,
                        ),
                        const SizedBox(height: 16),
                        ActionButton(
                          text: localizations.translate('clock_out'),
                          color: const Color(0xFFE57373),
                          icon: Icons.camera_alt,
                          onPressed: () => _navigateToVerificationScreen(false),
                        ),
                      ],
                    ),
                  ),
                ),

                // Location and Time Footer
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                text: localizations.translate(
                                    'current_location'),
                                style: const TextStyle(color: Colors.white),
                                children: [
                                  TextSpan(
                                    text: ' ($_timeString)',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Exit Button
                      ElevatedButton.icon(
                        icon: const Icon(
                            Icons.exit_to_app, color: Colors.white),
                        label: Text(localizations.translate('exit'),
                            style: const TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          primary: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          StorageService.deleteAll();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Bottom bar indicator
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  width: 150,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatefulWidget {
  final String text;
  final Color color;
  final IconData icon;
  final VoidCallback onPressed;

  const ActionButton({
    super.key,
    required this.text,
    required this.color,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: isHovered ? widget.color.withOpacity(0.8) : widget.color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isHovered
              ? [
            BoxShadow(
              color: widget.color.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}