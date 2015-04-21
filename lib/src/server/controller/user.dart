library user_controller;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import '../app.dart';
import '../firebase.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/shared_util.dart';

class UserController {
  static createNewUser(App app, HttpRequest request) async {
    String dataReceived;

    await request.listen((List<int> buffer) {
      dataReceived = new String.fromCharCodes(buffer);
    }).asFuture();

    Map data = JSON.decode(dataReceived);
    String username = (data['username'] as String).toLowerCase();
    String facebookId = data['facebookId']; // We may have a facebookId if they're a temporary user.

    var lookForExistingUser = await findUserInfo(username);
    if (lookForExistingUser != null) return Response.fromError('That username is not available.'); // User already exists.

    String newSessionId = app.sessionManager.createSessionId();
    var authToken;

    // Prepare the data for save and response.
    DateTime now = new DateTime.now().toUtc();
    data['.priority'] = -now.millisecondsSinceEpoch;
    data['createdDate'] = now.toString();
    data['password'] = hash(data['password']);
    data['disabled'] = data['invitation'] == null; // If we have don't have an invitation, user starts as disabled.

    if (data['onboardingState'] == 'temporaryUser') {
      // Update the references in the relevant indexes to the new username.
      var dataToUpdate = {'username': username};
      Firebase.patch('/facebook_index/$facebookId.json', dataToUpdate, auth: config['datastore']['firebaseSecret']);
      Firebase.patch('/session_index/$facebookId.json', dataToUpdate, auth: config['datastore']['firebaseSecret']);

      // Get some things from the old user data.
      Map oldUserData = await Firebase.get('/users/$facebookId.json');
      data['picture'] = oldUserData['picture'];

      // Delete the old user data.
      Firebase.delete('/users/$facebookId.json', auth: config['datastore']['firebaseSecret']);

    } else {
      // TODO: Consider simplifying auth so just checks user == user, so we don't have to wait for session index.
      Map newSession = await app.sessionManager.addSessionToIndex(newSessionId, username);
      data['authToken'] = newSession['authToken'];
      // If the user isn't disabled (i.e. they  have an invitation) send down a session to sign them in.
      if (!data['disabled']) app.sessionManager.addSessionCookieToRequest(request, newSessionId);
    }

    // Update the onboarding state now that we created the user.
    data['onboardingState'] = 'signUpComplete';

    // Create the new user.
    Firebase.put('/users/$username.json', data, auth: config['datastore']['firebaseSecret']);

    // Prepare the data for response.
    data.remove('password'); // The client doesn't need the password.
    data.remove('.priority');

    var response = new Response();
    response.data = data;
    response.success = true;
    return response;
  }

  static Future findUserInfo(String username) => Firebase.get('/users/$username.json');
}