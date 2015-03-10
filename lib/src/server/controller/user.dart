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
      String username = (data['username'] as String).toLowerCase();

      return findUserInfo(username).then((userData) {
        if (userData != null) return Response.fromError('User already exists.');
        String newSessionId = app.sessionManager.createSessionId();

        // TODO: Consider simplifying auth so just checks user == user, so we don't have to wait for session index.
        return app.sessionManager.addSessionToIndex(newSessionId, username).then((sessionData) {
          // Prepare the data for save and response.
          DateTime now = new DateTime.now().toUtc();
          data['createdDate'] = now.toString();
          data['password'] = hash(data['password']);
          data['.priority'] = -now.millisecondsSinceEpoch;

          app.sessionManager.addSessionCookieToRequest(request, newSessionId);

          // Create the new user.
          return Firebase.put('/users/$username.json', data, auth: sessionData['authToken']).then((response) {
            // Prepare the data for response.
            data['authToken'] = sessionData['authToken'];
            data.remove('password'); // The client doesn't need the password.
            data.remove('.priority');

            var response = new Response();
            response.data = data;
            response.success = true;
            return response;
          });
        });
      });
    });
  }

  static Future findUserInfo(String username) => Firebase.get('/users/$username.json');
}