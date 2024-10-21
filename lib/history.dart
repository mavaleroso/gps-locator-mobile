import 'package:flutter/material.dart';
import 'package:locationtrackingapp/activity_detail.dart';
import 'package:locationtrackingapp/model/activity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';

class History extends StatefulWidget {
  const History({Key? key}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Activity History'),
      ),
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
    );
  }
}
