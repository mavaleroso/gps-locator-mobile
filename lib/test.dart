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
  List<List<LatLng>> allRoutes = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Route Map")),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(49.41461, 8.681495),
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.app',
          ),
          if (allRoutes.isNotEmpty)
            PolylineLayer(
              polylines: allRoutes.asMap().entries.map((entry) {
                final index = entry.key;
                final route = entry.value;

                final color = index == 0 ? Colors.blue : Colors.grey;

                return Polyline(
                  points: route,
                  strokeWidth: 4.0,
                  color: color,
                );
              }).toList(),
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
        "coordinates": [start, end],
        "alternative_routes": {
          "target_count": 3,
          "weight_factor": 2.8,
          "share_factor": 1.2
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List routes = data['routes'];

      List<List<LatLng>> newRoutes = [];

      // for (var route in routes) {
      //   final encodedPolyline = route['geometry'];
      //   PolylinePoints polylinePoints = PolylinePoints();
      //   List<PointLatLng> decodedPoints =
      //       polylinePoints.decodePolyline(encodedPolyline);

      //   newRoutes.add(decodedPoints
      //       .map((point) => LatLng(point.latitude, point.longitude))
      //       .toList());
      //   // final decodedPolyline = decodePolyline(encodedPolyline);

      //   // newRoutes.add(decodedPolyline);
      // }

      for (var route in routes) {
        final encodedPolyline = route['geometry'];
        final decodedPolyline = decodePolyline(encodedPolyline);

        newRoutes.add(decodedPolyline);
      }

      setState(() {
        allRoutes = newRoutes;
      });

      print("Routes fetched: ${allRoutes.length}");
    } else {
      print("Error: ${response.reasonPhrase}");
    }
  }

  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
