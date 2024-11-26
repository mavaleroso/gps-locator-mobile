import 'package:flutter/material.dart';
import 'package:locationtrackingapp/activity_detail.dart';
import 'package:locationtrackingapp/model/activity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';

class History extends StatefulWidget {
  const History({super.key});

  @override
  _HistoryState createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  List<Activity> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  // Load activities from local storage
  Future<void> _loadActivities() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? activityList = prefs.getStringList('activities');

    if (activityList != null) {
      setState(() {
        _activities = activityList
            .map((activity) => Activity.fromJson(jsonDecode(activity)))
            .toList();
      });
    }
  }

  // Navigate to detail page
  void _navigateToActivityDetail(Activity activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityDetail(activity: activity),
      ),
    );
  }

  void clearSharedPreferences() async {
    // Access shared preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Clear all preferences
    await prefs.clear();

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All activity is cleared!')),
    );

    setState(() {
      _activities = []; // Empty list after clearing storage
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: _activities.length,
        itemBuilder: (context, index) {
          final activity = _activities[index];
          return ListTile(
            title: Text('Activity ${activity.id}'),
            subtitle: Text('Recorded at ${activity.time}'),
            onTap: () => _navigateToActivityDetail(activity),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: clearSharedPreferences,
        tooltip: 'Reset',
        backgroundColor: Colors.red[300],
        foregroundColor: Colors.white,
        child: const Icon(Icons.delete_forever_rounded),
      ),
    );
  }
}
