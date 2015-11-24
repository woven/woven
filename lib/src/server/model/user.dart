library server.model.user;

import 'dart:async';
import 'package:woven/src/shared/model/user.dart' as shared;
import 'package:woven/config/config.dart';
import '../firebase.dart';

class UserModel extends shared.UserModel {

  /**
   * Get the username formatted for display, i.e. case-sensitive.
   */
  static Future<String> usernameForDisplay(String user) async {
    user = user.toLowerCase();
    var username = await Firebase.get('/users/$user/username.json');
    if (username == null) return new Future.value(user);
    return username;
  }

  /**
   * Get the full path to the user picture.
   */
  static Future<String> getFullPathToPicture(String user) async {
    user = user.toLowerCase();
    var picture = await Firebase.get('/users/$user/pictureSmall.json');

    return picture != null ? "${config['google']['cloudStorage']['path']}/$picture" : null;
  }
}