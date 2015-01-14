library user_picture;

import "dart:html";

import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart';

import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';

@CustomTag("user-picture")
class UserPicture extends PolymerElement {
  @published App app;
  @published String user;
  @observable Map userMap;

  var fb = new Firebase(config['datastore']['firebaseLocation']);

  UserPicture.created() : super.created();

  getUser() {
    if (user != null) {
      fb.child('/users/$user').once('value').then((res) {
        userMap = res.val();
        userMap['fullPicturePath'] = '${config['google']['cloudStoragePath']}/${userMap['picture']}';
      });

    }
  }

  userChanged() {
    getUser();
  }

  attached() {
    getUser();
  }
}