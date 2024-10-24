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
  const Record({super.key});

  @override
  _RecordState createState() => _RecordState();
}

class _RecordState extends State<Record> {
  LatLng _currentLocation = const LatLng(14.5995, 120.9842); // Default Manila
  late MapController _mapController;
  bool _locationFetched = false;
  final List<LatLng> _drawing = []; // Path for recording
  bool _isRecording = false;
  Duration _elapsedTime = Duration.zero;
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;
  List<String>? activityList = [];

  // Define your 5 destination coordinates
  final List<LatLng> _destinations = [
    LatLng(8.956495, 125.528629), // Manila
    LatLng(8.941064, 125.540044), // Quezon City
    LatLng(8.943862, 125.524681), // Makati
    LatLng(8.942124, 125.535367), // Pasig
    LatLng(8.959208, 125.527041), // Taguig
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    SharedPreferences prefs = await SharedPreferences.getInstance();

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    LocationSettings locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
      forceLocationManager: true,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      _updateLocation(position, prefs);
    });
  }

  void _updateLocation(Position position, SharedPreferences prefs) {
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _locationFetched = true;
      _mapController.move(_currentLocation, 18.0);

      if (_isRecording) {
        _drawing.add(_currentLocation);
        String activityId = DateTime.now().millisecondsSinceEpoch.toString();
        Activity newActivity = Activity(
            id: activityId, coordinates: _drawing, time: DateTime.now());

        activityList = prefs.getStringList('activities') ?? [];
        activityList?.add(jsonEncode(newActivity.toJson()));
      }
    });
  }

  void _toggleRecording() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      _isRecording = !_isRecording;

      if (_isRecording) {
        _drawing.clear();
        _elapsedTime = Duration.zero;

        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _elapsedTime += const Duration(seconds: 1);
          });
        });
      } else {
        _timer?.cancel();
        prefs.setStringList('activities', activityList!);
      }
    });
  }

  void _moveToCurrentLocation() {
    _mapController.move(_currentLocation, 18.0);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitsHours = twoDigits(duration.inHours);
    String twoDigitsMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitsSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitsHours:$twoDigitsMinutes:$twoDigitsSeconds';
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
                  points: _drawing,
                  color: Colors.amberAccent,
                  strokeWidth: 4.0,
                ),
              ],
            ),
          // Add markers for each destination
          MarkerLayer(
            markers: _destinations
                .asMap()
                .entries
                .map(
                  (entry) => Marker(
                    point: entry.value,
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                        Text('Destination ${entry.key + 1}'),
                      ],
                    ),
                  ),
                )
                .toList(),
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
              tooltip: 'Go to Current Location',
              child: Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    onPressed: _toggleRecording,
                    tooltip:
                        _isRecording ? 'Stop Recording' : 'Start Recording',
                    backgroundColor: _isRecording ? Colors.red : Colors.amber,
                    child: Icon(_isRecording
                        ? Icons.stop
                        : Icons.play_circle_fill_rounded),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_elapsedTime),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
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
