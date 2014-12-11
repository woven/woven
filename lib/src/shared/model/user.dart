library user_model;

import 'package:woven/config/config.dart';

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

  static Map encode(UserModel user) {
    return {
      "username": user.username,
      "firstName": user.firstName,
      "lastName": user.lastName,
      "email": user.email,
      "facebookId": user.facebookId,
      "location": user.location,
      "gender": user.gender,
      "picture": user.picture,
      "createdDate": user.createdDate,
      "disabled": user.disabled
    };
  }

  static UserModel decode(Map data) {
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