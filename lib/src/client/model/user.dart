library user_model_client;

import 'dart:async';
import 'package:woven/src/shared/model/user.dart' as shared;
import 'package:woven/src/client/cache.dart';
import 'package:firebase/firebase.dart';

class UserModel extends shared.UserModel {

  /**
   * Get the username formatted for display, i.e. case-sensitive.
   */
  static Future<String> usernameForDisplay(String user, Firebase f, Cache cache) {
    // Find the case-ified username, from app cache or directly.
    user = user.toLowerCase();
    if (cache.users.containsKey(user)) {
      if (cache.users[user] == null) {
        return new Future.value('Unknown');
      }
      return new Future.value(cache.users[user].username);
    } else {
      return f.child('/users/$user/username').once('value').then((res) {
        if (res.val() == null) return new Future.value(user);
        return res.val();
      });
    }
  }
}