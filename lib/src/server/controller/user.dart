library user_controller;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import '../mail_sender.dart';
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
    String email = (data['email'] as String).toLowerCase();
    String invitationCode = data['invitationCode'];
    data['disabled'] = false; // User is disabled by default, may be enabled below.

    var lookForExistingUser = await findUserInfo(username);
    if (lookForExistingUser != null) return Response.fromError('That username is not available.'); // User already exists.

    // Give user instant access in certain cases.
    if (data['invitation'] != null) {
      data['disabled'] = false;
    } else if (data['invitationCode'] != null) {
      if (await findInvitationCode(data['invitationCode']) == null) {
        return Response.fromError('That\'s not a valid invitation code. Try leaving that field blank.');
      } else {
        data['disabled'] = false;
        data['invitation'] = {'code': invitationCode};
      }
    }

    String newSessionId = app.sessionManager.createSessionId();

    // Prepare the data for save and response.
    DateTime now = new DateTime.now().toUtc();
    data['_priority'] = -now.millisecondsSinceEpoch;
    data['createdDate'] = now.toString();
    data['password'] = hash(data['password']);

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
    }

    // TODO: Consider simplifying auth so just checks user == user, so we don't have to wait for session index.
    Map newSession = await app.sessionManager.addSessionToIndex(newSessionId, username);
    data['authToken'] = newSession['authToken'];
    // If the user isn't disabled (i.e. they  have an invitation) send down a session to sign them in.
    app.sessionManager.addSessionCookieToRequest(request, newSessionId);

    // Update the onboarding state now that we created the user.
    data['onboardingState'] = 'signUpComplete';

    // Prepare the data before adding.
    data.remove('invitationCode');

    // Create the new user.
    await Firebase.put('/users/$username.json', data, auth: config['datastore']['firebaseSecret']);
    // When the user completes the welcome dialog, send them a welcome email.
    MailSender.sendWelcomeEmail(username);

    // Add the user's email address to the email index so we can look up later by email.
    Firebase.put('/email_index/${encodeFirebaseKey(data['email'])}.json', {'user': username, 'email': email}, auth: config['datastore']['firebaseSecret']);

    Map dataForResponse = new Map.from(data);

    // Prepare the data for response.
    dataForResponse.remove('password'); // The client doesn't need the password.
    dataForResponse.remove('_priority');

    var response = new Response();
    response.data = dataForResponse;
    response.success = true;
    return response;
  }

  static Future findUserInfo(String username) => Firebase.get('/users/$username.json');

  static Future findInvitationCode(String code) => Firebase.get('/invitation_code_index/$code.json');
}