import 'dart:convert';

class UserModel {
  String? userName;
  String userEmail;
  String dob;
  String? ref;
  UserModel(
      {required this.dob, this.userName, this.ref, required this.userEmail});

  String toJson() {
    return jsonEncode(
        {'userName': userName, 'dob': dob, 'ref': ref, 'userEmail': userEmail});
  }

  factory UserModel.fromJson(String jsonString) {
    Map<String, dynamic> json = jsonDecode(jsonString);
    return UserModel(
        userName: json['userName'].toString(),
        dob: json['dob'],
        ref: json['ref'].toString().trim(),
        userEmail: json['userEmail'].toString().trim());
  }
}
