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
  // String _userName = 'Guest';
  // String _userEmail = 'guest@example.com';
  UserModel me =
      UserModel(dob: 'uk', userEmail: 'guest@example.com', userName: 'Guest');
  List<UserModel> _groupMembers = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadGroupMembers();
    _loadTimeTable();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? json = prefs.getString('user');
    if (json == null) {
      return;
    }
    UserModel user = UserModel.fromJson(json);
    setState(() {
      me = user;
      // _userName = user.userName?.trim() ?? 'Guest';
      // _userEmail = user.userEmail.trim().toLowerCase();
    });
  }

  Future<void> _loadTimeTable() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // String? json = prefs.getString('user');
    // if (json == null) {
    //   return;
    // }
    // UserModel user = UserModel.fromJson(json);

    List<String> refs = [];
    refs.add(me.ref ?? '');

    _groupMembers.forEach((m) => refs.add(m.ref ?? ''));

    Set<dynamic> uniqueTimetable = {};

    for (String ref in refs) {
      if (ref.isNotEmpty) {
        try {
          List<dynamic> timetable =
              await _apiService.getStudentTimeTableForAttendance(ref);

          for (var element in timetable) {
            bool contains = false;
            for (var ut in uniqueTimetable) {
              if (ut['timeTableId'] == element['timeTableId']) {
                contains = true;
                break;
              }
            }
            if (!contains) {
              uniqueTimetable.add(element);
            }
          }

          // uniqueTimetable.addAll(timetable);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching timetable for ref $ref')),
          );
          debugPrint("Error fetching timetable for ref $ref: $e");
        }
      }
    }

    setState(() {
      _timetable = uniqueTimetable.toList();
    });

    // try {
    //   List<dynamic> timetable =
    //       await _apiService.getStudentTimeTableForAttendance(user.ref ?? '');
    //   setState(() {
    //     _timetable = timetable;
    //   });
    // } catch (e) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Center(child: Text('$e'))),
    //   );
    //   debugPrint("Error fetching timetable: $e");
    // }
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
    final resp =
        await ApiService().login(user.userEmail, user.dob, group: true);

    if (resp != null) {
      return UserModel(
          dob: user.dob,
          userEmail: user.userEmail,
          ref: resp[0]['referenceId'],
          userName: resp[0]['studentName']);
    }
    return null;
  }

  Future<void> _addGroupMember(UserModel member, BuildContext context) async {
    if (me.userEmail == member.userEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Center(child: Text('You cannot add yourself to your group'))),
      );
      return;
    }
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

                _addGroupMember(
                    UserModel(dob: password, userEmail: userName), context);
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
    // await prefs.clear();
    await prefs.remove('user');
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

  Future<void> _markAttendanceDialog(String timetableId) async {
    int? choice = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: const Text('Mark attendance?'),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(0), // Return 0 for "Mark for me"
              child: const Text('Mark for me',
                  style: TextStyle(color: Colors.teal)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pop(1), // Return 1 for "Mark for everyone"
              child: const Text('Mark for everyone',
                  style: TextStyle(color: Colors.teal)),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(null), // Return null for "Cancel"
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (choice == null) {
      return;
    }

    await markAttendance(timetableId, me);

    if (choice == 1) {
      for (var user in _groupMembers) {
        await markAttendance(timetableId, user);
      }
    }
  }

  Future<void> markAttendance(String timetableId, UserModel user) async {
    String? refId = user.ref;

    if (refId != null) {
      try {
        dynamic x = await _apiService.upsertStudentAttendanceDetails(
            refId, timetableId);
        if (x == 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Center(
                    child: Text(
                        'Failed to mark attendance for ${user.userName}'))),
          );
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Center(
                  child: Text(
                      'Attendance marked successfully for ${user.userName}'))),
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
              accountName: Text(me.userName?.toUpperCase() ?? 'Guest'),
              accountEmail: Text(me.userEmail.toUpperCase()),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  me.userName != null && me.userName!.isNotEmpty
                      ? me.userName![0]
                      : 'G',
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
                      _markAttendanceDialog(course['timeTableId']);
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
