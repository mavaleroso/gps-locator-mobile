import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:locationtrackingapp/model/activity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

class Record extends StatefulWidget {
  const Record({super.key});

  @override
  _RecordState createState() => _RecordState();
}

class _RecordState extends State<Record> {
  LatLng _currentLocation = const LatLng(8.9517, 125.5297); // Default Manila
  LatLng? nearestDestination;
  late MapController _mapController;
  bool _locationFetched = false;
  final List<LatLng> _drawing = []; // Path for recording
  bool _isRecording = false;
  Duration _elapsedTime = Duration.zero;
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;
  List<String>? activityList = [];
  List<LatLng> _routeCoordinates = [];
  final String _orsApiKey =
      '5b3ce3597851110001cf62486f61daf8bee1425a93f93d9f99e49416'; // Add your ORS API Key here

  // Define your 5 destination coordinates
  final List<Map<String, dynamic>> _destinations = [
    {
      'location': LatLng(8.952399, 125.529228),
      'delivered': false,
      'deliveredAt': null
    },
    {
      'location': LatLng(8.953652, 125.528008),
      'delivered': false,
      'deliveredAt': null
    },
    {
      'location': LatLng(8.954917, 125.528586),
      'delivered': false,
      'deliveredAt': null
    },
  ];

  final double _proximityThreshold = 20.0; // 5 meters radius

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

    _showRouteToNearestDestination();

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      _updateLocation(position, prefs);
    });
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // Earth radius in km

    double dLat = _degreesToRadians(end.latitude - start.latitude);
    double dLon = _degreesToRadians(end.longitude - start.longitude);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(start.latitude)) *
            cos(_degreesToRadians(end.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c; // Distance in km
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  LatLng _findNearestDestination() {
    LatLng nearestDestination = _destinations.first['location'];
    double minDistance =
        _calculateDistance(_currentLocation, nearestDestination);

    for (var destination in _destinations) {
      double distance =
          _calculateDistance(_currentLocation, destination['location']);
      if (distance < minDistance) {
        minDistance = distance;
        nearestDestination = destination['location'];
      }
    }
    return nearestDestination;
  }

  Future<void> _getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/foot-walking?api_key=$_orsApiKey&start=${start.longitude},${start.latitude}&end=${end.longitude},${end.latitude}',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coordinates =
          data['features'][0]['geometry']['coordinates'] as List<dynamic>;

      setState(() {
        _routeCoordinates = coordinates
            .map((coord) => LatLng(coord[1] as double, coord[0] as double))
            .toList();
      });
    } else {
      print('Failed to load route: ${response.statusCode}');
    }
  }

  void _showRouteToNearestDestination() {
    nearestDestination = _findNearestDestination();
    _getRoute(_currentLocation, nearestDestination!);
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
          id: activityId,
          coordinates: _drawing,
          time: DateTime.now(),
        );

        activityList = prefs.getStringList('activities') ?? [];
        activityList?.add(jsonEncode(newActivity.toJson()));

        _checkProximityAndShowBottomSheet();
      }
    });
  }

  void _checkProximityAndShowBottomSheet() {
    for (var destination in _destinations) {
      final LatLng destinationLocation = destination['location'];
      final bool delivered = destination['delivered'];

      if (!delivered) {
        double distance = Geolocator.distanceBetween(
          _currentLocation.latitude,
          _currentLocation.longitude,
          destinationLocation.latitude,
          destinationLocation.longitude,
        );

        if (distance <= _proximityThreshold && _isRecording) {
          // Show the bottom sheet asking for delivery confirmation
          _showDeliveryConfirmation(destination);
          break; // Exit loop once a nearby destination is found
        }
      }
    }
  }

  void _showDeliveryConfirmation(Map<String, dynamic> destination) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Confirm Delivery',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Is the item delivered at this destination?'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    // Update the destination's delivered status to true
                    destination['delivered'] = true;
                    destination['deliveredAt'] = DateTime.now().toString();
                  });
                  Navigator.pop(context); // Close the bottom sheet
                },
                child: const Text('Delivered'),
              ),
            ],
          ),
        );
      },
    );
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

  // Method to show bottom sheet with list of destinations
  void _showDestinationsList() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Destinations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap:
                    true, // Allow the list to take only the necessary space
                itemCount: _destinations.length,
                itemBuilder: (BuildContext context, int index) {
                  final destination = _destinations[index];
                  final delivered = destination['delivered'] as bool;
                  final deliveredAt = destination['deliveredAt'] as String?;

                  return ListTile(
                    title: Text('Destination ${index + 1}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Location: (${destination['location'].latitude}, ${destination['location'].longitude})'),
                        Text(
                            'Status: ${delivered ? 'Delivered' : 'Not Delivered'}'),
                        if (deliveredAt !=
                            null) // Show the delivered timestamp if available
                          Text('Delivered at: $deliveredAt'),
                      ],
                    ),
                    trailing: delivered
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.circle_outlined, color: Colors.red),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _moveToDestination(LatLng destination) {
    print(
        'Move to destination: ${destination.latitude}, ${destination.longitude}');
    // You can integrate this with a map controller to move to the destination
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery Route"),
        actions: [
          IconButton(
              icon: const Icon(Icons.directions),
              onPressed: _showRouteToNearestDestination),
        ],
      ),
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
                  strokeWidth: 6.0,
                ),
              ],
            ),
          if (_routeCoordinates.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _routeCoordinates,
                  color: Colors.blue,
                  strokeWidth: 6.0,
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
                    point: entry.value['location'] as LatLng,
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        const Icon(
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
              backgroundColor: Colors.white,
              onPressed: _moveToCurrentLocation,
              tooltip: 'Go to Current Location',
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
              bottom: 16,
              left: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  FloatingActionButton(
                    backgroundColor: Colors.amber[300],
                    onPressed: _showDestinationsList,
                    tooltip: 'Current Delivery',
                    child: const Icon(Icons.delivery_dining),
                  ),
                  // Badge
                  Positioned(
                    top: 5,
                    left: 5,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_destinations.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              )),
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
