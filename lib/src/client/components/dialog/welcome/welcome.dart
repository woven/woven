import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'package:firebase/firebase.dart' as db;
import 'package:core_elements/core_overlay.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';
import 'package:core_elements/core_input.dart';
import 'package:core_elements/core_selector.dart';
import '../../../../shared/model/user.dart';

@CustomTag('welcome-dialog')
class WelcomeDialog extends PolymerElement {
  WelcomeDialog.created() : super.created();
  @published App app;

  CoreOverlay get overlay => $['welcome-overlay'];

  // *
  // Toggle the overlay.
  // *
  toggleOverlay() {
    overlay.toggle();
//    name.focus(); //Doesn't work
  }

  // *
  // Add an item.
  // *
  updateUser(Event e) {
    e.preventDefault();

//    CoreSelector type = $['content-type'];
    CoreInput firstname = $['firstname'];
    CoreInput lastname = $['lastname'];
    CoreInput email = $['email'];
    CoreInput username = $['username'];

    if (username.inputValue.trim().isEmpty) {
      window.alert("You must choose a username.");
      return false;
    }

    var firebaseLocation = config['datastore']['firebaseLocation'];

    var user = new UserModel()
      ..username = username.inputValue
      ..firstName = firstname.inputValue
      ..lastName = lastname.inputValue
      ..email = email.inputValue
      ..facebookId = app.user.facebookId;


    final userData = new db.Firebase("$firebaseLocation/users/${username.inputValue}");

    // If username is changing, update the Facebook index
    // and remove the old user record.
    if (username.inputValue != app.user.username) {
      final indexRef = new db.Firebase("$firebaseLocation/facebook_index/${app.user.facebookId}");
      final oldUserRef = new db.Firebase("$firebaseLocation/users/${app.user.username}");

      Future set(db.Firebase indexRef) {
        indexRef.set({'username': '${username.inputValue}'});
      }

      set(indexRef);

      Future remove(db.Firebase oldUserRef) {
        oldUserRef.remove();
      }

      remove(oldUserRef);

      // Update the client's user object.
      app.user = user;
    }

//    DateTime now = new DateTime.now().toUtc();

    Future set(db.Firebase userData) {
      userData.set(user.encode()).then((e){
//        print("User updated: ${body.value}");
      });
    }

    set(userData);
    overlay.toggle();
//    body.value = "";
//    subject.value = "";
//
//    if (app.user != null) {
//      app.user.username = name.inputValue;
//    }
//
//    app.selectedPage = 0;
  }

  attached() {
    //
  }
}

