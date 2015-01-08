library user_model;

import 'package:woven/config/config.dart';
import 'dart:convert';

class UserModel {
  String id;
  String username;
  String firstName;
  String lastName;
  String location;
  String gender;
  String picture;
  String facebookId;
  String email;
  String createdDate;
  bool isNew = false;
  bool disabled = false;

  String get fullPathToPicture => picture != null ? "${config['google']['cloudStoragePath']}/$picture" : null;

  Map toJson() {
    return {
      "username": username,
      "firstName":firstName,
      "lastName": lastName,
      "email": email,
      "facebookId": facebookId,
      "location": location,
      "gender": gender,
      "picture": picture,
      "createdDate": createdDate,
      "disabled": disabled
    };
  }

  static UserModel fromJson(Map data) {
    if (data == null) return null;
    return new UserModel()
      ..firstName = data['firstName']
      ..lastName = data['lastName']
      ..username = data['username']
      ..email = data['email']
      ..facebookId = data['facebookId']
      ..location = data['location']
      ..gender = data['gender']
      ..picture = data['picture']
      ..createdDate = data['createdDate']
      ..disabled = data['disabled'];
  }
}