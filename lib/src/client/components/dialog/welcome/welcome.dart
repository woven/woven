import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'package:firebase/firebase.dart' as f;
import 'package:core_elements/core_overlay.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';
import 'package:core_elements/core_input.dart';
import 'package:core_elements/core_selector.dart';
import '../../../../shared/model/user.dart';

import 'package:woven/src/shared/routing/routes.dart';


@CustomTag('welcome-dialog')
class WelcomeDialog extends PolymerElement {
  WelcomeDialog.created() : super.created();
  @published App app;

  CoreOverlay get overlay => $['welcome-overlay'];

  /**
   * Toggle the welcome overlay.
   */
  toggleOverlay() {
    overlay.toggle();
  }

  /**
   * Create a new user by updating the temporary one.
   */
  updateUser(Event e) {
    e.preventDefault();

    CoreInput firstname = $['firstname'];
    CoreInput lastname = $['lastname'];
    CoreInput email = $['email'];
    CoreInput username = $['username'];
    CoreInput location = $['location'];

    if (username.value.trim().isEmpty) {
      window.alert("You must choose a username.");
      return false;
    }

    //TODO: Regex this for all disallowed cases.
    if (username.value.trim().contains(" ")) {
      window.alert("Your username may not contain spaces.");
      return false;
    }

    final fRoot = new f.Firebase(config['datastore']['firebaseLocation']);

    DateTime now = new DateTime.now().toUtc();

    // If username is changing, update the Facebook index
    // and remove the old user record.
    if (username.value != app.user.username) {
      final facebookIndexRef = fRoot.child('/facebook_index/${app.user.facebookId}');
      final tempUserRef = fRoot.child('/users/${app.user.username}');
      final userRef = fRoot.child('/users/${username.value}');
      var epochTime = DateTime.parse(now.toString()).millisecondsSinceEpoch;

      // Move the old user data to its new location and update it.
      Future updateUser() {
        facebookIndexRef.set({'username': '${username.value}'});
        tempUserRef.once('value').then((snapshot) {
          Map oldUserData = snapshot.val();
          return oldUserData;
        }).then((oldUserData) {
          var user = new UserModel()
            ..username = username.value
            ..firstName = firstname.value
            ..lastName = lastname.value
            ..email = email.value
            ..facebookId = app.user.facebookId
            ..picture = oldUserData['picture']
            ..location = location.value
            ..gender = app.user.gender
            ..createdDate = now.toString()
            ..isNew = true;

          userRef.setWithPriority(oldUserData, -epochTime);
          tempUserRef.remove();
          userRef.update(user.toJson());

          // Update the client's user instance.
          app.user = user;
        });
      }

      updateUser();
    }

    overlay.toggle();
    app.user.isNew = true;

    // When the user completes the welcome dialog, send them a welcome email.
    HttpRequest.request(Routes.sendWelcome.toString());
  }

  attached() {
    //
  }
}

