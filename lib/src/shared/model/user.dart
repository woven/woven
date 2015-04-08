library user_model;

import 'package:woven/config/config.dart';

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
  OnboardingStatus onboardingStatus;

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
      "needsPassword": needsPassword,
      "onboardingStatus": enumToName(onboardingStatus)
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
      ..needsPassword = data['needsPassword']
      ..onboardingStatus = data['onboardingStatus'];
  }
}

/**
 * Converts enum value to string, because there's no toString().
 */
String enumToName(OnboardingStatus onboardingStatus) {
  if (onboardingStatus == OnboardingStatus.temporaryUser) return 'temporaryUser';
  if (onboardingStatus == OnboardingStatus.signUpComplete) return 'signUpComplete';
  if (onboardingStatus == OnboardingStatus.onboardingComplete) return 'onboardingComplete';
}

/**
 * Defines valid/recognized onboarding statuses associated with a user.
 */
enum OnboardingStatus {
  signUpComplete, // User has chosen a username and password.
  onboardingComplete, // User has completed the initial onboarding flow. TODO: Not used atm.
  temporaryUser // For when we have a temporary user created with information from FB or Tw, which needs to be updated.
}