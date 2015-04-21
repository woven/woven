library user_picture;

import 'package:polymer/polymer.dart';

import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/model/user.dart';

@CustomTag("user-picture")
class UserPicture extends PolymerElement {
  @published App app;
  @published String username;
  @observable UserModel user;

  UserPicture.created() : super.created();

  getUser() {
    if (username == null) return;

    // Check the app cache for the user.
    if (app.cache.users.containsKey(username)) {
      user = app.cache.users[username];
    } else {
      app.f.child('/users/$username').once('value').then((res) {
        if (res == null) return;
        user = UserModel.fromJson(res.val());
        app.cache.users[username] = user;
      });
    };
  }

  usernameChanged() {
    getUser();
  }

  attached() {
    getUser();
  }
}