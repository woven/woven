library user_picture;

import "dart:html";

import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart';

import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/config/config.dart';

import 'dart:convert';

@CustomTag("user-picture")
class UserPicture extends PolymerElement {
  @published App app;
  @published String username;
  @observable UserModel user;

  var fb = new Firebase(config['datastore']['firebaseLocation']);

  UserPicture.created() : super.created();

  getUser() {
    if (username == null) return;

    if (app.user != null && username == app.user.username) {
      // If we're trying to show the current user, we already know its details.
      user = app.user;
    } else {
      // Check the app cache for the user.
      if (app.cache.users.containsKey(username)) {
        user = app.cache.users[username];
      } else {
        print('query');
        fb.child('/users/$username').once('value').then((res) {
          if (res == null) return;
          user = UserModel.fromJson(res.val());
          app.cache.users[username] = user;
        });
      };
    }
  }

  userChanged() {
    getUser();
  }

  attached() {
    getUser();
  }
}