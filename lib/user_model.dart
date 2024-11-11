import 'dart:convert';

class UserModel {
  String userName;
  String dob;
  UserModel({required this.dob, required this.userName});

  String toJson() {
    return jsonEncode({'userName': userName, 'dob': dob});
  }

  factory UserModel.fromJson(String jsonString) {
    Map<String, dynamic> json = jsonDecode(jsonString);
    return UserModel(
      userName: json['userName'],
      dob: json['dob'],
    );
  }
}
