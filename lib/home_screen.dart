// home_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/login.dart';
import 'package:timetable/user_model.dart';
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
  List<UserModel> _groupMembers = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTimeTable();
    _loadGroupMembers();
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
        debugPrint("Error fetching timetable: $e");
      }
    } else {
      debugPrint("Reference ID not found");
    }
  }

  Future<void> _loadGroupMembers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> memberJsonList = prefs.getStringList('groupMembers') ?? [];

    setState(() {
      _groupMembers =
          memberJsonList.map((json) => UserModel.fromJson(json)).toList();
    });
  }

  Future<UserModel?> _validateUser(UserModel user) async {
    final resp = await ApiService().login(user.userEmail, user.dob);

    if (resp != null) {
      return UserModel(
          dob: user.dob,
          userEmail: user.userEmail,
          ref: resp[0]['referenceId'],
          userName: resp[0]['studentName']);
    }
    return null;
  }

  Future<void> _addGroupMember(UserModel member) async {
    bool alreadyExists =
        _groupMembers.any((m) => m.userEmail == member.userEmail);

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Center(child: Text('User already exists in your group'))),
      );
      return;
    }

    UserModel? user = await _validateUser(member);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Center(
                child: Text('Failed to validate user, Check credintials!'))),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _groupMembers.add(user);

      List<String> memberJsonList =
          _groupMembers.map((m) => m.toJson()).toList();
      prefs.setStringList('groupMembers', memberJsonList);
    });
  }

  Future<void> _removeGroupMember(UserModel member) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _groupMembers.remove(member);
      List<String> memberJsonList =
          _groupMembers.map((m) => m.toJson()).toList();
      prefs.setStringList('groupMembers', memberJsonList);
    });
  }

  void _showGroupMembersSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Group Members',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _groupMembers.length,
                      itemBuilder: (context, index) {
                        final member = _groupMembers[index];
                        return ListTile(
                          title: Text(member.userName != null
                              ? member.userName!.toUpperCase()
                              : member.userEmail),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              bool? confirm =
                                  await _confirmRemoveMember(member);
                              if (confirm == true) {
                                setState(() {
                                  _groupMembers.remove(member);
                                });
                                _saveGroupMembers();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _showAddMemberDialog(),
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.teal),
                      child: const Center(
                          child: Text(
                        'Add Member',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      )),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveGroupMembers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> memberJsonList = _groupMembers.map((m) => m.toJson()).toList();
    prefs.setStringList('groupMembers', memberJsonList);
  }

  Future<void> _showAddMemberDialog() async {
    final TextEditingController usernamecontroller = TextEditingController();
    final TextEditingController dobcontroller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Member'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: usernamecontroller,
              decoration: const InputDecoration(hintText: 'Enter Roll Number'),
            ),
            TextField(
              controller: dobcontroller,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(hintText: 'Enter Password(DOB)'),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (usernamecontroller.text.trim() == '' ||
                    dobcontroller.text.trim() == '') {
                  return;
                }

                final userName = usernamecontroller.text.trim().toLowerCase();
                final password = dobcontroller.text.trim();

                _addGroupMember(UserModel(dob: password, userEmail: userName));
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmRemoveMember(UserModel member) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: const Text(
              'Are you sure you want to remove this user from your group?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.green)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    return confirm;
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // await prefs.remove('referenceId');
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
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.green)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _logout();
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
              decoration: const BoxDecoration(color: Colors.teal),
            ),
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Your Group'),
              onTap: () {
                Navigator.of(context).pop(); // Close the drawer
                _showGroupMembersSheet();
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
                    date: course['attendanceDate'].split('-')[0],
                    month: course['attendanceDate'].split('-')[1],
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
