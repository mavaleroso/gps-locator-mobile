import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:locationtrackingapp/model/activity.dart';
import 'package:flutter/scheduler.dart'; // For the TickerProvider
import 'dart:math';

class ActivityDetail extends StatefulWidget {
  final Activity activity;

  const ActivityDetail({super.key, required this.activity});

  @override
  _ActivityDetailState createState() => _ActivityDetailState();
}

class _ActivityDetailState extends State<ActivityDetail>
    with SingleTickerProviderStateMixin {
  late MapController _mapController;
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<LatLng> _animatedPath = [];
  bool _isAnimating = false;

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

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Set up the AnimationController
    _animationController = AnimationController(
      duration:
          const Duration(seconds: 20), // Increased duration for smoothness
      vsync: this,
    );

    // Applying an easing curve to the animation
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    )..addListener(() {
        _animatePath();
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Interpolate between two points for smooth animation
  LatLng _interpolate(LatLng start, LatLng end, double t) {
    final lat = start.latitude + (end.latitude - start.latitude) * t;
    final lng = start.longitude + (end.longitude - start.longitude) * t;
    return LatLng(lat, lng);
  }

  // Animate the path smoothly by interpolating between points
  void _animatePath() {
    final int totalPoints = widget.activity.coordinates.length;

    if (totalPoints > 1) {
      final double scaledValue = _animation.value * (totalPoints - 1);
      final int index = scaledValue.floor();
      final double t = scaledValue - index;

      // Interpolate between two points for smoother transition
      final LatLng startPoint = widget.activity.coordinates[index];
      final LatLng endPoint =
          widget.activity.coordinates[min(index + 1, totalPoints - 1)];
      final LatLng currentPosition = _interpolate(startPoint, endPoint, t);

      setState(() {
        _animatedPath = widget.activity.coordinates.sublist(0, index + 1);
        _animatedPath
            .add(currentPosition); // Append current interpolated position
      });

      // Move the map view to the current position
      _mapController.move(currentPosition, 18);
    }
  }

  // Start animation
  void _startAnimation() {
    setState(() {
      _isAnimating = true;
      _animatedPath.clear(); // Clear the previous path
    });
    _animationController.forward(
        from: 0.0); // Start animation from the beginning
  }

  // Stop animation
  void _stopAnimation() {
    _animationController.stop(); // Stop the animation
    setState(() {
      _isAnimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Details'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.activity.coordinates.isNotEmpty
                  ? widget.activity.coordinates[0]
                  : const LatLng(0, 0),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              if (_animatedPath.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _animatedPath,
                      color: Colors.amber,
                      strokeWidth: 7.0,
                    ),
                  ],
                ),
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
            ],
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: Row(
              children: [
                FloatingActionButton(
                  onPressed: _isAnimating ? _stopAnimation : _startAnimation,
                  backgroundColor: _isAnimating ? Colors.red : Colors.amber,
                  child: Icon(_isAnimating ? Icons.stop : Icons.play_arrow),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
