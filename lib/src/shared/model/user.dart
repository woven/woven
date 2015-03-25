library user_model;

import 'package:woven/config/config.dart';
import 'dart:convert';

class UserModel {
  String id;
  String username; // This is the username formatted for display, i.e. case sensitive.
  String password;
  String firstName;
  String lastName;
  String location;
  String gender;
  String picture;
  String pictureSmall;
  String facebookId;
  String email;
  Map settings = {};
  String createdDate;
  bool isNew = false;
  bool disabled = false;
  bool needsPassword = false;

  // Return the path to the small picture if we have it, otherwise the original picture.
  String get fullPathToPicture => picture != null ? "${config['google']['cloudStoragePath']}/${pictureSmall != null ? pictureSmall : picture}" : null;

  Map toJson() {
    return {
      "username": username,
      "password": password,
      "firstName":firstName,
      "lastName": lastName,
      "email": email,
      "facebookId": facebookId,
      "location": location,
      "gender": gender,
      "picture": picture,
      "pictureSmall": pictureSmall,
      "settings": settings,
      "createdDate": createdDate,
      "disabled": disabled,
      "needsPassword": needsPassword
    };
  }

  static UserModel fromJson(Map data) {
    if (data == null) return null;
    return new UserModel()
      ..firstName = data['firstName']
      ..lastName = data['lastName']
      ..username = data['username']
      ..password = data['password']
      ..email = data['email']
      ..facebookId = data['facebookId']
      ..location = data['location']
      ..gender = data['gender']
      ..picture = data['picture']
      ..pictureSmall = data['pictureSmall']
      ..settings = data['settings']
      ..createdDate = data['createdDate']
      ..disabled = data['disabled']
      ..needsPassword = data['needsPassword'];
  }
}