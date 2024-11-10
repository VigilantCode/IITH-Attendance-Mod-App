// home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/login.dart';
import 'card.dart';
import 'api_services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _timetable = [];

  @override
  void initState() {
    super.initState();
    _loadTimeTable();
  }

  Future<void> _loadTimeTable() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? refId = prefs.getString('referenceId');

    if (refId != null) {
      try {
        List<dynamic> timetable =
            await _apiService.getStudentTimeTableForAttendance(refId);
        setState(() {
          _timetable = timetable;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Center(child: Text('$e'))),
        );
        // Handle error (e.g., show a dialog or a snackbar)
        debugPrint("Error fetching timetable: $e");
      }
    } else {
      // Handle the case where referenceId is not available
      debugPrint("Reference ID not found");
    }
  }

  Future<void> markAttendance(String timetableId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? refId = prefs.getString('referenceId');

    if (refId != null) {
      try {
        dynamic x = await _apiService.upsertStudentAttendanceDetails(
            refId, timetableId);
        if (x == 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Center(child: Text('Failed to mark attendance'))),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Center(child: Text('Attendance marked successfully'))),
        );
        _loadTimeTable();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Center(child: Text('$e'))),
        );
        debugPrint("Error marking attendance: $e");
      }
    } else {
      debugPrint("Reference ID not found");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Schedule'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 24),
            child: InkWell(
              onTap: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.remove('referenceId');
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                    (route) => false);
              },
              child: const Icon(Icons.logout),
            ),
          )
        ],
      ),
      body: _timetable.isNotEmpty
          ? ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _timetable.length,
              itemBuilder: (context, index) {
                var course = _timetable[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: EventCard(
                    onMarkAttendance: () {
                      markAttendance(course['timeTableId']);
                    },
                    date: course['attendanceDate']
                        .split('-')[0], // Extract the day
                    month: course['attendanceDate']
                        .split('-')[1], // Extract the month
                    title: course['courseName'],
                    instructor: course['facultyName'],
                    time: course['timePeriod'],
                    status:  course['attendanceMarked'] ? "DONE" :  course['isAttendanceMarkApplicable'] == 0 ? "N/A" : "PENDING",
                  ),
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
