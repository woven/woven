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
  }

  // *
  // Add an item.
  // *
  updateUser(Event e) {
    e.preventDefault();

    CoreInput firstname = $['firstname'];
    CoreInput lastname = $['lastname'];
    CoreInput email = $['email'];
    CoreInput username = $['username'];
    CoreInput location = $['location'];

    if (username.inputValue.trim().isEmpty) {
      window.alert("You must choose a username.");
      return false;
    }

    //TODO: Regex this for all disallowed cases.
    if (username.inputValue.trim().contains(" ")) {
      window.alert("Your username may not contain spaces.");
      return false;
    }

    var firebaseLocation = config['datastore']['firebaseLocation'];

    DateTime now = new DateTime.now().toUtc();

    var user = new UserModel()
      ..username = username.inputValue
      ..firstName = firstname.inputValue
      ..lastName = lastname.inputValue
      ..email = email.inputValue
      ..facebookId = app.user.facebookId
      ..location = location.inputValue
      ..createdDate = now.toString()
      ..isNew = true;


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

    Future set(db.Firebase userData) {
      userData.set(user.encode());
    }

    set(userData);
    overlay.toggle();

    app.user.isNew = true;
  }

  attached() {
    //
  }
}

