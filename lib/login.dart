import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timetable/user_model.dart';
import 'api_services.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  void _checkLoginStatus() async {
    bool loggedIn = await _apiService.isLoggedIn();
    if (loggedIn) {
      _navigateToHome();
    }
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (ctx) => const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )));

      final response = await _apiService.login(username, password);

      if (response == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Center(
                  child: Text('Login failed! Please check your credentials.'))),
        );
        return;
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      // await prefs.setString('referenceId', response[0]['referenceId']);
      // await prefs.setString('userEmail', username);
      // await prefs.setString('userName', response[0]['studentName']);

      final user = UserModel(
          userEmail: username,
          userName: response[0]['studentName'],
          ref: response[0]['referenceId'],
          dob: password);

      await prefs.setString('user', user.toJson());

      _navigateToHome();

      // if (success) {
      //   _navigateToHome();
      // } else {
      //   Navigator.pop(context);
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(
      //         content: Center(
      //             child: Text('Login failed! Please check your credentials.'))),
      //   );
      // }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            'Attendance',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Login to Your Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildTextField(
                    controller: _usernameController,
                    labelText: 'Username',
                    prefixIcon: Icons.person,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                      controller: _passwordController,
                      labelText: 'Password',
                      prefixIcon: Icons.lock,
                      obscureText: true,
                      type: TextInputType.number),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String labelText,
      required IconData prefixIcon,
      bool obscureText = false,
      TextInputType type = TextInputType.text}) {
    return TextFormField(
      keyboardType: type,
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(prefixIcon, color: Colors.teal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.teal),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $labelText';
        }
        return null;
      },
    );
  }
}
