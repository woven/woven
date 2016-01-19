library server.util.user_util;

import 'dart:async';

import 'package:woven/src/server/firebase.dart';
import 'package:woven/src/shared/util.dart';

Future<bool> isValidLogin(String username, String password) async {
  String hashedPassword = hash(password);
  var response = await Firebase.get('/users/$username/password.json');
  if (response == null) return false;
  return response == hashedPassword; // True if they match.
}

Future<bool> isDisabledUser(String username) async {
  var response = await Firebase.get('/users/$username/disabled.json');
  if (response == null) return false;
  return response;
}

Future findUserInfo(String username) => Firebase.get('/users/$username.json');

Future<bool> userExists(String user) {
  return Firebase.get('/users/$user.json').then((res) {
    return (res == null ? false : true);
  });
}

Future findFacebookIndex(String id) {
  return Firebase.get('/facebook_index/$id.json').then((res) {
    return res;
  });
}

Future findInvitationCode(String code) =>
    Firebase.get('/invitation_code_index/$code.json');
Future findUser(String username) => Firebase.get('/users/$username.json');
Future findSession(String sessionId) =>
    Firebase.get('/session_index/$sessionId.json');
Future findUsernameFromSession(String sessionId) =>
    Firebase.get('/session_index/$sessionId/username.json');
Future findUsernameFromFacebookIndex(String facebookId) =>
    Firebase.get('/facebook_index/$facebookId/username.json');
