library user_controller;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart' as shelf;

import '../mail_sender.dart';
import '../app.dart';
import '../firebase.dart';
import '../util.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/shared_util.dart';

class UserController {
  static createNewUser(App app, shelf.Request request) async {
    Map data = JSON.decode(await request.readAsString());
    String username = (data['username'] as String).toLowerCase();
    String facebookId = data['facebookId']; // We may have a facebookId if they're a temporary user.
    String email = (data['email'] as String).toLowerCase();
    String invitationCode = data['invitationCode'];
    data['disabled'] = false; // User is disabled by default, may be enabled below.
    Map headers;

    var lookForExistingUser = await findUserInfo(username);
    if (lookForExistingUser != null) return respond(Response.fromError('That username is not available.')); // User already exists.

    // Give user instant access in certain cases.
    if (data['invitation'] != null) {
      data['disabled'] = false;
    } else if (data['invitationCode'] != null) {
      if (await findInvitationCode(data['invitationCode']) == null) {
        return respond(Response.fromError('That\'s not a valid invitation code. Try leaving that field blank.'));
      } else {
        data['disabled'] = false;
        data['invitation'] = {'code': invitationCode};
      }
    }

    // If the user isn't disabled (i.e. they  have an invitation) send down a session to sign them in.
    String sessionId = app.sessionManager.createSessionId();

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
    } else {
      // TODO: Consider simplifying auth so just checks user == user, so we don't have to wait for session index.
      Map newSession = await app.sessionManager.addSessionToIndex(sessionId, username);
      data['authToken'] = newSession['authToken'];
      headers = (data['disabled'] ? {} : app.sessionManager.getSessionHeaders(sessionId));
    }

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
    return new shelf.Response.ok(JSON.encode(response), headers: headers);
  }

  static Future<shelf.Response> getCurrentUser(App app, shelf.Request request) async {
    var sessionCookie = app.sessionManager.getSessionCookie(request);
    if (sessionCookie == null) return respond(Response.fromError('No session cookie found.'), statusCode: 401);
    if (sessionCookie.value == null) return respond(Response.fromError('The id in the session cookie was null.'), statusCode: 401);

    var sessionId = sessionCookie.value;

    // Check the session index for the user associated with this session id.
    Map sessionData = await findSession(sessionId);
    if (sessionData == null) {
      // The user may have an old cookie, with Facebook ID, so let's check that index.
      String username = await findUsernameFromFacebookIndex(sessionId);
      if (username == null) {
        return respond(Response.fromError('A session with that id was not found.'), statusCode: 401);
      } else {
        // Update the old cookie to use a newer session ID, and add it to our session index.
        sessionId = app.sessionManager.createSessionId();
        sessionData = await app.sessionManager.addSessionToIndex(sessionId, username.toLowerCase());
      }
    }

    String authToken = sessionData['authToken'];
    String username = (sessionData['username'] as String).toLowerCase();

    // If the session has no auth token, just generate a new session.
    if (sessionData['authToken'] == null) {
      sessionId = app.sessionManager.createSessionId();
      sessionData = await app.sessionManager.addSessionToIndex(sessionId, username);
      authToken = sessionData['authToken'];
    }

    // Return the user data.
    Map userData = await findUser(username);
    var response = new Response();

    if (userData == null) return respond(Response.fromError('That user was not found.'), statusCode: 401);

//    if (userData['disabled'] == true) return Response.fromError('That user is not active.');

    if (userData['password'] == null) userData['needsPassword'] = true;
    userData.remove('password');

    if (authToken == null) {
      sessionId = app.sessionManager.createSessionId();
      sessionData = await app.sessionManager.addSessionToIndex(sessionId, username);
      userData['auth_token'] = sessionData['authToken'];
      response.data = userData;
    } else {
      userData['auth_token'] = authToken;
      response.data = userData;
    }

    return new shelf.Response.ok(JSON.encode(response), headers: app.sessionManager.getSessionHeaders(sessionId));
  }

  static signOut(App app, shelf.Request request) {
    return new shelf.Response.ok('', headers: app.sessionManager.deleteCookie());
  }

  static signIn(App app, shelf.Request request) async {
    // Check for a session cookie in the request.
    var sessionCookie = app.sessionManager.getSessionCookie(request);
    // If there's an existing session cookie, use it. Else, create a new session id.
    var sessionId = (sessionCookie == null || sessionCookie.value == null) ? app.sessionManager.createSessionId() : sessionCookie.value;


    Map<String, String> data = JSON.decode(await request.readAsString());
    var username = data['username'].toLowerCase();
    var password = data['password'];

    if (!(await isValidLogin(username, password))) return respond(Response.fromError('We don\'t recognize you. Try again.'), statusCode: 403);

//    if (!(await isDisabledUser(username))) return respond(Response.fromError('You don\'t have access yet.\n\nWant to talk about it? hello@woven.co'), statusCode: 403);

    var sessionData = await app.sessionManager.addSessionToIndex(sessionId, username);
    Map userData = await findUserInfo(username);


    var response = new Response();
    userData['authToken'] = sessionData['authToken'];
    userData.remove('password');
    response.data = userData;
    response.success = true;

    return new shelf.Response.ok(JSON.encode(response), headers: app.sessionManager.getSessionHeaders(sessionId));
  }

  static Future<bool> isValidLogin(String username, String password) async {
    String hashedPassword = hash(password);
    var response = await Firebase.get('/users/$username/password.json');
    if (response == null) return false;
    return response == hashedPassword; // True if they match.
  }

  static Future<bool> isDisabledUser(String username) async {
    var response = await Firebase.get('/users/$username/disabled.json');
    if (response == null) return false;
    return response;
  }

  static Future findUserInfo(String username) => Firebase.get('/users/$username.json');

  static Future<bool> userExists(String user) {
    return Firebase.get('/users/$user.json').then((res) {
      return (res == null ? false : true);
    });
  }

  static Future findFacebookIndex(String id) {
    return Firebase.get('/facebook_index/$id.json').then((res) {
      return res;
    });
  }

  static Future findInvitationCode(String code) => Firebase.get('/invitation_code_index/$code.json');
  static Future findUser(String username) => Firebase.get('/users/$username.json');
  static Future findSession(String sessionId) => Firebase.get('/session_index/$sessionId.json');
  static Future findUsernameFromSession(String sessionId) => Firebase.get('/session_index/$sessionId/username.json');
  static Future findUsernameFromFacebookIndex(String facebookId) => Firebase.get('/facebook_index/$facebookId/username.json');
}