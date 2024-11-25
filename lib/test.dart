import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class Test extends StatefulWidget {
  @override
  _TestState createState() => _TestState();
}

class _TestState extends State<Test> {
  List<LatLng> routePoints = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Route Map")),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(8.681495, 49.41461), // Example center (Paris)
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.app',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: routePoints,
                strokeWidth: 4.0,
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.directions),
        onPressed: _getRoute,
      ),
    );
  }

  Future<void> _getRoute() async {
    final start = [8.681495, 49.41461]; // Example start point
    final end = [8.687872, 49.420318]; // Example end point
    final apiKey = "5b3ce3597851110001cf62486f61daf8bee1425a93f93d9f99e49416";

    final response = await http.post(
      Uri.parse("https://api.openrouteservice.org/v2/directions/foot-walking"),
      headers: {
        "Authorization": apiKey,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "coordinates": [start, end]
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final encodedPolyline =
          data['routes'][0]['geometry']; // Get encoded polyline

      // Decode polyline
      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> decodedPoints =
          polylinePoints.decodePolyline(encodedPolyline);

      setState(() {
        routePoints = decodedPoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(); // Convert to LatLng for Leaflet
      });
    } else {
      print("Error: ${response.reasonPhrase}");
    }
  }
}
