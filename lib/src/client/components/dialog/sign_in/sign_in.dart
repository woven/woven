import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:convert';
import 'package:firebase/firebase.dart' as f;
import 'package:core_elements/core_overlay.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';
import 'package:core_elements/core_input.dart';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'package:woven/src/client/util.dart';
import '../welcome/welcome.dart';

import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';

@CustomTag('sign-in-dialog')
class SignInDialog extends PolymerElement {
  SignInDialog.created() : super.created();

  @published App app;
  @published bool opened = false;

  final fRoot = new f.Firebase(config['datastore']['firebaseLocation']);

  CoreOverlay get overlay => $['dialog-overlay'];
  CoreInput get username => $['username'];
  CoreInput get password => $['password'];

  DateTime get now => new DateTime.now().toUtc();

  /**
   * Toggle the overlay.
   */
  toggleOverlay() => overlay.toggle();

  /**
   * Submit the form and choose what to do.
   */
  submit(Event e) {
    e.preventDefault();

    doSignIn();
  }

  /**
   * Handle sign in.
   */
  doSignIn() {
    if (username.value.trim().isEmpty || password.value.trim().isEmpty) {
      window.alert("Your username and password, please.");
      return false;
    }

    // Check credentials and sign the user in server side.
    HttpRequest.request(
        Routes.signIn.toString(),
        method: 'POST',
        sendData: JSON.encode({'username': username.value, 'password': password.value}))
    .then((HttpRequest request) {
      print(request.responseText);
      // Set up the response as an object.
      Response response = Response.fromJson(JSON.decode(request.responseText));
      if (response.success) {
        // Set up the user.
        UserModel user = UserModel.fromJson(response.data);
        app.user = user;
        // Mark as new so the welcome pops up.
        app.user.isNew = true;
        overlay.toggle();
      } else {
        window.alert("We don't recognize you. Try again.");
      }
    });
  }

  toggleSignUp() {
    WelcomeDialog welcome = document.querySelector('woven-app').shadowRoot.querySelector('welcome-dialog');
    this.toggleOverlay();
    welcome.toggleOverlay();
  }

  signInWithFacebook() {
    app.signInWithFacebook();
  }

  attached() {
    //
  }
}

