library user_controller;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:query_string/query_string.dart';
import 'package:http/http.dart' as http;
import '../app.dart';
import '../firebase.dart';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'package:woven/src/server/util.dart';

class UserController {
  static createNewUser(App app, HttpRequest request) {
    HttpResponse response = request.response;
    String dataReceived;

    return request.listen((List<int> buffer) {
      dataReceived = new String.fromCharCodes(buffer);
    }).asFuture().then((_) {
      Map data = JSON.decode(dataReceived);
      DateTime now = new DateTime.now().toUtc();
      // Set the created date.
      data['createdDate'] = now.toString();
      // Hash the password.
      data['password'] = hash(data['password']);
      data['.priority'] = -now.millisecondsSinceEpoch;
      String username = (data['username'] as String).toLowerCase();
      return findUserInfo(username).then((userData) {
        // User already exists.
        if (userData != null) return Response.fromError('User already exists.');
        // Generate a Firebase authentication token. TODO: Put this elsewhere?
        app.authToken = generateFirebaseToken({'uid': username});
        // Create the new user.
        return Firebase.put('/users/$username.json', data, app.authToken).then((response) {
          // Create a session cookie and add the session to the session index.
          String newSessionId = app.sessionManager.createSessionId();
          app.sessionManager.addSessionCookieToRequest(request, newSessionId);
          app.sessionManager.addSessionToIndex(newSessionId, username, app.authToken);

          var response = new Response();
          response.data = data;
          response.success = true;
          return response;
        });
      });
    });
  }

//  static Future<bool> userExists(String user) {
//    return Firebase.get('/users/$user.json').then((res) {
//      return (res == null ? false : true);
//    });
//  }

  static Future findUserInfo(String username) => Firebase.get('/users/$username.json');
}