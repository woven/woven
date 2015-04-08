library user_controller;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:query_string/query_string.dart';
import 'package:http/http.dart' as http;
import 'package:gravatar/gravatar.dart';

import '../app.dart';
import '../firebase.dart';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'package:woven/src/server/util.dart';

class UserController {
  static createNewUser(App app, HttpRequest request) async {
    String dataReceived;

    await request.listen((List<int> buffer) {
      dataReceived = new String.fromCharCodes(buffer);
    }).asFuture();

    Map data = JSON.decode(dataReceived);
    print(data);
    String username = (data['username'] as String).toLowerCase();

    var lookForExistingUser = await findUserInfo(username);
    if (lookForExistingUser != null) return Response.fromError('That username is not available.'); // User already exists.

    String newSessionId = app.sessionManager.createSessionId();

    if (data['status'] == 'temporaryUser') {
      print('debug');

    } else {
      // TODO: Consider simplifying auth so just checks user == user, so we don't have to wait for session index.
      Map newSession = await app.sessionManager.addSessionToIndex(newSessionId, username);

      // Prepare the data for save and response.
      DateTime now = new DateTime.now().toUtc();

      data['createdDate'] = now.toString();
      data['password'] = hash(data['password']);
      data['onboardingStatus'] = 'signUpComplete';
      data['disabled'] = true;
      data['.priority'] = -now.millisecondsSinceEpoch;

//      app.sessionManager.addSessionCookieToRequest(request, newSessionId);

      // Create the new user.
      Firebase.put('/users/$username.json', data, auth: newSession['authToken']);

      // Add the auth to the data before we respond with it.
      data['authToken'] = newSession['authToken'];
    }

    // Prepare the data for response.
    data.remove('password'); // The client doesn't need the password.
    data.remove('.priority');

    var response = new Response();
    response.data = data;
    response.success = true;
    return response;
  }

//  /**
//   * Create a new user from a temporary Facebook user (i.e. before a username has been chosen).
//   *
//   * Updates the Facebook index and removes the old user record.
//   */
//  static updateTemporaryUser(App app, HttpRequest request) {
//    HttpResponse response = request.response;
//    String dataReceived;
//
//    return request.listen((List<int> buffer) {
//      dataReceived = new String.fromCharCodes(buffer);
//    }).asFuture().then((_) {
//      Map data = JSON.decode(dataReceived);
//      String username = (data['username'] as String).toLowerCase();
//      String facebookId = (data['username'] as String).toLowerCase();
//
////    final facebookIndexRef = f.child('/facebook_index/${app.user.facebookId}');
////    final sessionIndexRef = f.child('/session_index/${app.sessionId}');
////    final tempUserRef = f.child('/users/${app.user.username.toLowerCase()}');
////    var epochTime = DateTime.parse(now.toString()).millisecondsSinceEpoch;
//
//      // Move the old user data to its new location and update it.
//      var dataToUpdate = {'username': username, '.priority': ''};
//
//      Firebase.patch('/facebook_index/${facebookId}', dataToUpdate, auth: config['datastore']['firebaseSecret']);
//      Firebase.patch('/session_index/${facebookId}', dataToUpdate, auth: config['datastore']['firebaseSecret']);
//
//      var snapshot = await Firebase.get('/users/$TODO');
//      Map oldUserData = snapshot.val();
//
//      // Prepare the data for save and response.
//      DateTime now = new DateTime.now().toUtc();
//      data['createdDate'] = now.toString();
//      data['password'] = hash(data['password']);
//      data['onboardingStatus'] = 'signUpComplete';
//      data['disabled'] = true;
//      data['.priority'] = -now.millisecondsSinceEpoch;
//
//      var user = new UserModel()
//        ..username = username
//        ..password = data['password']
//        ..firstName = data['firstName']
//        ..lastName = data['lastName']
//        ..email = data['email']
//        ..facebookId = data['facebookId']
//        ..picture = oldUserData['picture']
//        ..createdDate = now.toString()
//        ..isNew = true;
//
//  //    userRef.setWithPriority(oldUserData, -epochTime);
//        Firebase.delete('/users/$TODO');
//        Firebase.patch('/users/$TODO', user.toJson(), auth: config['datastore']['firebaseSecret']);
//
//        // Update the client's user instance.
////        app.user = user;
////        app.user.isNew = true;
//      });
//    }
//  }

  static Future findUserInfo(String username) => Firebase.get('/users/$username.json');

  static getGravatarForEmail(String email) {
    var gravatar = new Gravatar(email);
    print(gravatar.imageUrl(size: 2048) + '&d=404');
  }
}