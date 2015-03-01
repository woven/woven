import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:firebase/firebase.dart' as f;
import 'package:core_elements/core_overlay.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';
import 'package:core_elements/core_input.dart';
import 'package:core_elements/core_selector.dart';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/shared/shared_util.dart';

import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';


@CustomTag('welcome-dialog')
class WelcomeDialog extends PolymerElement {
  WelcomeDialog.created() : super.created();

  @published App app;
  @published bool opened = false;

  final fRoot = new f.Firebase(config['datastore']['firebaseLocation']);

  CoreOverlay get overlay => $['welcome-overlay'];

  CoreInput get firstname => $['firstname'];
  CoreInput get lastname => $['lastname'];
  CoreInput get email => $['email'];
  CoreInput get username => $['username'];
  CoreInput get password => $['password'];
  CoreInput get location => $['location'];

  DateTime get now => new DateTime.now().toUtc();

  /**
   * Toggle the welcome overlay.
   */
  toggleOverlay() => overlay.toggle();

  /**
   * Submit the form and choose what to do.
   */
  submit(Event e) {
    e.preventDefault();

    if (email.value.trim().isEmpty) {
      window.alert("Please provide your email.");
      return false;
    }

    if (username.value.trim().isEmpty) {
      window.alert("Please choose a username.");
      return false;
    }

    //TODO: Regex this for all disallowed cases.
    if (username.value.trim().contains(" ")) {
      window.alert("Your username may not contain spaces.");
      return false;
    }

    if (password.value.trim().isEmpty || password.value.trim().length < 6) {
      window.alert("Please choose a password at least 6 characters long.");
      return false;
    }

    if (firstname.value.trim().isEmpty || lastname.value.trim().isEmpty) {
      window.alert("Please give us your full name so we can be cordial.");
      return false;
    }

    if (app.user == null) {
      createNewUser();
    } else {
      if (username.value != app.user.username) updateTemporaryUser();
      if (username.value == app.user.username) updateExistingUser();
    }

//    overlay.toggle();

    // When the user completes the welcome dialog, send them a welcome email.
//    HttpRequest.request(Routes.sendWelcome.toString());
  }

  /**
   * Handle various close scenarios.
   */
  close(Event e) {
    if (app.user != null) {
      // Let submit take over if we have a user and
      // don't want to allow closing the dialog.
      submit(e);
    } else {
      toggleOverlay();
    }
  }

  /**
   * Create a new user.
   */
  createNewUser() {
    // Check credentials and sign the user in server side.
    HttpRequest.request(
        Routes.createNewUser.toString(),
        method: 'POST',
        sendData: JSON.encode({
            'username': username.value,
            'password': password.value,
            'firstName': firstname.value,
            'lastName': lastname.value,
            'email': email.value
              }))
    .then((HttpRequest request) {
      print(request.responseText);
      // Set up the response as an object.
      Response response = Response.fromJson(JSON.decode(request.responseText));
      if (response.success) {
        // Set up the user.
        UserModel user = UserModel.fromJson(response.data);
        app.user = user;
        // Mark as new so the welcome pops up.
        app.showMessage('Welcome to Woven, ${app.user.firstName}!');
        overlay.toggle();
      }
    });
  }

  /**
   * Create a new user from a temporary Facebook user (i.e. before a username has been chosen).
   *
   * Updates the Facebook index and removes the old user record.
   */
  updateTemporaryUser() {
    final userRef = fRoot.child('/users/${username.value}');
    final facebookIndexRef = fRoot.child('/facebook_index/${app.user.facebookId}');
    final sessionIndexRef = fRoot.child('/session_index/${app.sessionId}');
    final tempUserRef = fRoot.child('/users/${app.user.username}');
    var epochTime = DateTime.parse(now.toString()).millisecondsSinceEpoch;

    // Move the old user data to its new location and update it.
    Future updateUser() {

      facebookIndexRef.setWithPriority({'username': '${username.value}'}, -epochTime);
      sessionIndexRef.setWithPriority({'username': '${username.value}'}, -epochTime);

      return tempUserRef.once('value').then((snapshot) {
        Map oldUserData = snapshot.val();
        return oldUserData;
      }).then((oldUserData) {
        var user = new UserModel()
          ..username = username.value
          ..password = hash(password.value)
          ..firstName = firstname.value
          ..lastName = lastname.value
          ..email = email.value
          ..facebookId = app.user.facebookId
          ..picture = oldUserData['picture']
          ..gender = app.user.gender
          ..createdDate = now.toString()
          ..isNew = true;

        userRef.setWithPriority(oldUserData, -epochTime);
        tempUserRef.remove();
        userRef.update(user.toJson());

        // Update the client's user instance.
        app.user = user;
        app.user.isNew = true;
        overlay.toggle();
      });
    }

    updateUser();
  }

  /**
   * Updates an existing user.
   */
  updateExistingUser() {
    final userRef = fRoot.child('/users/${username.value}');

    var user = new UserModel()
      ..username = username.value
      ..password = hash(password.value)
      ..firstName = convertEmptyToNull(firstname.value)
      ..lastName = convertEmptyToNull(lastname.value)
      ..email = convertEmptyToNull(email.value);
    Map userData = removeNullsFromMap(user.toJson());
    userRef.update(userData);

    // Update the client's user instance.
    app.user = user;
    app.showMessage('Thanks for doing that, ${app.user.firstName}.');
    overlay.toggle();
  }

  attached() {
    //
  }
}

