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

  String get fullPathToPicture {
    if (picture == null) return null;
    return "${config['google']['cloudStoragePath']}/$picture";
  }

  Map encode() {
    return {
      "username": username,
      "firstName": firstName,
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
