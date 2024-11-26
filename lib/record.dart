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
import 'package:signature/signature.dart';

class Record extends StatefulWidget {
  const Record({super.key});

  @override
  _RecordState createState() => _RecordState();
}

class _RecordState extends State<Record> {
  LatLng _currentLocation = const LatLng(8.9505, 125.5301); // Default Manila
  LatLng? nearestDestination;
  late MapController _mapController;
  bool _locationFetched = false;
  final List<LatLng> _drawing = []; // Path for recording
  bool _isRecording = false;
  Duration _elapsedTime = Duration.zero;
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;
  List<String>? activityList = [];
  final List<LatLng> _routeCoordinates = [];
  final String _orsApiKey =
      '5b3ce3597851110001cf62486f61daf8bee1425a93f93d9f99e49416'; // Add your ORS API Key here
  List<Polyline> _routePolylines = [];

  final TextEditingController _nameController = TextEditingController();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  bool _isDeliveryModalOpen = false; // Flag to prevent repeated modals

  // Define your 5 destination coordinates
  final List<Map<String, dynamic>> _destinations = [
    {
      'location': const LatLng(8.952399, 125.529228),
      'delivered': false,
      'deliveredAt': null
    },
    {
      'location': const LatLng(8.953652, 125.528008),
      'delivered': false,
      'deliveredAt': null
    },
    {
      'location': const LatLng(8.954917, 125.528586),
      'delivered': false,
      'deliveredAt': null
    },
    {
      'location': const LatLng(8.9443585, 125.5285996),
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
    _nameController.dispose();
    _signatureController.dispose();
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
        'https://api.openrouteservice.org/v2/directions/foot-walking');
    final requestPayload = jsonEncode({
      "coordinates": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude]
      ],
      "alternative_routes": {
        "target_count": 2,
        "weight_factor": 1.4,
        "share_factor": 0.6
      }
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': _orsApiKey,
          'Content-Type': 'application/json',
        },
        body: requestPayload,
      );

      print(response.body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Polyline> alternativePolylines = [];

        // for (var feature in data['features']) {
        //   final coordinates =
        //       feature['geometry']['coordinates'] as List<dynamic>;
        //   final routeCoordinates = coordinates
        //       .map((coord) => LatLng(coord[1] as double, coord[0] as double))
        //       .toList();

        //   // Use different colors for alternative routes
        //   Color routeColor =
        //       alternativePolylines.isEmpty ? Colors.blue : Colors.grey.shade400;

        //   alternativePolylines.add(
        //     Polyline(
        //       points: routeCoordinates,
        //       strokeWidth: 4.0,
        //       color: routeColor,
        //     ),
        //   );
        // }
        // if (data['routes'] is List) {
        for (var route in data['routes']) {
          // Extract the encoded geometry and decode it into a list of coordinates
          final encodedGeometry = route['geometry'] as String;

          // Decode the polyline (OpenRouteService provides encoded geometry in "Polyline6" format)
          final routeCoordinates =
              decodePolyline(encodedGeometry, precision: 6);

          // Use different colors for alternative routes
          Color routeColor =
              alternativePolylines.isEmpty ? Colors.blue : Colors.grey.shade400;

          // Add the decoded route as a Polyline
          alternativePolylines.add(
            Polyline(
              points: routeCoordinates,
              strokeWidth: 4.0,
              color: routeColor,
            ),
          );
        }
        // } else {
        //   print("No routes available in the response.");
        // }
        setState(() {
          _routePolylines = alternativePolylines;
        });
      } else {
        print(
            'Failed to load route: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error while fetching route: $e');
    }
  }

// Helper function to decode an encoded polyline
  List<LatLng> decodePolyline(String polyline, {int precision = 6}) {
    List<LatLng> points = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      points.add(LatLng(lat / pow(10, precision), lng / pow(10, precision)));
    }

    return points;
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
    if (_isDeliveryModalOpen) return;

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
    setState(() {
      _isDeliveryModalOpen = true; // Set modal open flag to true
    });

    _nameController.clear();
    _signatureController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Container(
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

                  // Name input field
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Signature pad
                  const Text('Signature:'),
                  const SizedBox(height: 8),
                  Signature(
                    controller: _signatureController,
                    height: 150,
                    backgroundColor: Colors.grey[200]!,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          _signatureController.clear(); // Clear the signature
                        },
                        child: const Text('Clear Signature'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: () {
                      if (_nameController.text.isEmpty ||
                          _signatureController.isEmpty) {
                        // Show an error if name or signature is missing
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Please provide your name and signature'),
                          ),
                        );
                        return;
                      }

                      setState(() {
                        // Update the destination's delivered status
                        destination['delivered'] = true;
                        destination['deliveredAt'] = DateTime.now().toString();
                      });

                      Navigator.pop(context); // Close the bottom sheet
                    },
                    child: const Text('Confirm Delivery'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      // Reset the flag when modal is closed
      setState(() {
        _isDeliveryModalOpen = false;
      });
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
          PolylineLayer(
            polylines: _routePolylines,
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
                        GestureDetector(
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                          onTap: () {
                            // Call _getRoute with tapped destination coordinates
                            _getRoute(_currentLocation,
                                entry.value['location'] as LatLng);
                          },
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
