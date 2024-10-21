import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:locationtrackingapp/model/activity.dart';

class ActivityDetail extends StatelessWidget {
  final Activity activity;

  ActivityDetail({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Activity Details'),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: activity.coordinates.isNotEmpty
              ? activity.coordinates[0]
              : LatLng(0, 0), // Default center
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(
            markers: activity.coordinates.map((coord) {
              return Marker(
                point: coord,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 30,
                ),
              );
            }).toList(),
          ),
          if (activity.coordinates.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: activity.coordinates,
                  color: Colors.blue,
                  strokeWidth: 4.0,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
