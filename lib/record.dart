import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:locationtrackingapp/model/activity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class Record extends StatefulWidget {
  const Record({Key? key}) : super(key: key);

  @override
  _RecordState createState() => _RecordState();
}

class _RecordState extends State<Record> {
  // Default location set to Manila, Philippines
  LatLng _currentLocation = const LatLng(14.5995, 120.9842);
  late MapController _mapController;
  bool _locationFetched = false;
  List<LatLng> _path = [];

  Timer? _timer;
  Timer? _elapsedTimeTimer;
  bool _isRecording = false; // Track if recording is active
  double _lastLatitude = 14.5995; // Last known latitude
  double _lastLongitude = 120.9842; // Last known longitude
  Duration _elapsedTime = Duration.zero; // Timer duration

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the location update timer when disposing
    _elapsedTimeTimer?.cancel(); // Cancel the elapsed time timer when disposing
    super.dispose();
  }

  // Method to get the current location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Handle location services not being enabled
      return;
    }

    // Check and request location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Handle permission denied
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Handle permission permanently denied
      return;
    }

    // Get the current position
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    // Check if the distance moved is greater than 3 meters
    double distanceInMeters = Geolocator.distanceBetween(
      _lastLatitude,
      _lastLongitude,
      position.latitude,
      position.longitude,
    );

    // Update location only if moved more than 3 meters
    if (distanceInMeters > 1) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _locationFetched = true;
        _mapController.move(
            _currentLocation, 18.0); // Move map to current location

        // Add the current location to the path if recording
        if (_isRecording) {
          _path.add(_currentLocation);
          String activityId =
              DateTime.now().millisecondsSinceEpoch.toString(); // Unique ID
          Activity newActivity = Activity(
              id: activityId, coordinates: _path, time: DateTime.now());

          // Store activity in shared preferences
          List<String>? activityList = prefs.getStringList('activities') ?? [];
          activityList.add(jsonEncode(newActivity.toJson()));
          prefs.setStringList('activities', activityList);
        }

        // Update last known location
        _lastLatitude = position.latitude;
        _lastLongitude = position.longitude;
      });
    }
  }

  // Method to start/stop recording
  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording; // Toggle recording state

      if (_isRecording) {
        // Start recording, initialize path, and start the timer
        _path.clear(); // Clear the previous path
        _elapsedTime = Duration.zero; // Reset elapsed time
        _elapsedTimeTimer = Timer.periodic(Duration(seconds: 1), (timer) {
          setState(() {
            _elapsedTime += Duration(seconds: 1); // Increment elapsed time
          });
        });
        _timer = Timer.periodic(Duration(seconds: 5), (timer) {
          _getCurrentLocation(); // Update location
        });
      } else {
        // Stop recording and cancel the timers
        _timer?.cancel();
        _elapsedTimeTimer?.cancel();
      }
    });
  }

  // Method to move the map to the current location
  void _moveToCurrentLocation() {
    _mapController.move(_currentLocation, 18.0);
  }

  // Convert Duration to String
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitsHours = twoDigits(duration.inHours);
    String twoDigitsMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitsSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigitsHours}:${twoDigitsMinutes}:${twoDigitsSeconds}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentLocation,
          initialZoom: 18.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          if (_locationFetched)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _path,
                  color: Colors.amberAccent,
                  strokeWidth: 4.0,
                ),
              ],
            ),
          if (_locationFetched)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation,
                  width: 80,
                  height: 80,
                  child: const Icon(
                    Icons.my_location_rounded,
                    size: 50.0,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () =>
                    launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
              ),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _moveToCurrentLocation,
              child: Icon(Icons.my_location),
              tooltip: 'Go to Current Location',
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0, // Set left to 0
            right: 0, // Set right to 0
            child: Center(
              // Use Center widget
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center, // Center children vertically
                children: [
                  FloatingActionButton(
                    onPressed: _toggleRecording,
                    child: Icon(_isRecording
                        ? Icons.stop
                        : Icons.play_circle_fill_rounded),
                    tooltip:
                        _isRecording ? 'Stop Recording' : 'Start Recording',
                    backgroundColor: _isRecording ? Colors.red : Colors.amber,
                  ),
                  SizedBox(height: 8), // Space between button and timer
                  Text(
                    _formatDuration(_elapsedTime),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
