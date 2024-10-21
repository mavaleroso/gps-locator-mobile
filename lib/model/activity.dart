import 'package:latlong2/latlong.dart';

class Activity {
  final String id; // Unique identifier for the activity
  final List<LatLng> coordinates; // List of coordinates for the activity
  final DateTime time; // Timestamp of the activity

  Activity({required this.id, required this.coordinates, required this.time});

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coordinates': coordinates
          .map((coord) => {
                'latitude': coord.latitude,
                'longitude': coord.longitude,
              })
          .toList(),
      'time': time.toIso8601String(),
    };
  }

  // Create an Activity from JSON
  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'],
      coordinates: (json['coordinates'] as List)
          .map((coord) => LatLng(coord['latitude'], coord['longitude']))
          .toList(),
      time: DateTime.parse(json['time']),
    );
  }
}
