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

final _scaffoldKey = GlobalKey<ScaffoldState>();

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _timetable = [];
  String _userName = '';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTimeTable();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'Guest';
      _userEmail = prefs.getString('userEmail') ?? 'guest@example.com';
    });
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
            const SnackBar(
                content: Center(child: Text('Failed to mark attendance'))),
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

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('referenceId');
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (ctx) => const LoginScreen()),
        (route) => false);
  }

  Future<void> _confirmLogout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.green),),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.red),),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Today\'s Schedule'),
        actions: [
          IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer())
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(_userName.toUpperCase()),
              accountEmail: Text(_userEmail.toUpperCase()),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  _userName.isNotEmpty ? _userName[0] : '',
                  style: const TextStyle(fontSize: 40.0),
                ),
              ),
              decoration: const BoxDecoration(
                color: Colors.teal
              ),
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Your Group'),
              onTap: () {
                // Handle "Your Group" action
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _confirmLogout,
            ),
          ],
        ),
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
                    status: course['attendanceMarked']
                        ? "DONE"
                        : course['isAttendanceMarkApplicable'] == 0
                            ? "N/A"
                            : "PENDING",
                  ),
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
