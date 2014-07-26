library sign_in_controller;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:query_string/query_string.dart';
import 'package:http/http.dart' as http;
import '../app.dart';
import '../firebase.dart';
import '../../shared/model/user.dart';
import '../../../config/config.dart';

class SignInController {
  static facebook(App app, HttpRequest request) {
    print('Debug: SignInController.facebook()');

    var code        = Uri.encodeComponent(request.uri.queryParameters['code']);
    var appId       = Uri.encodeComponent(config['authentication']['facebook']['appId']);
    var appSecret   = Uri.encodeComponent(config['authentication']['facebook']['appSecret']);
    var callbackUrl = Uri.encodeComponent(config['authentication']['facebook']['url']);

    var url = 'https://graph.facebook.com/oauth/access_token?client_id=$appId&redirect_uri=$callbackUrl&client_secret=$appSecret&code=$code';
    return http.read(url).then((String contents) {
      // The contents look like this: access_token=USER_ACCESS_TOKEN&expires=NUMBER_OF_SECONDS_UNTIL_TOKEN_EXPIRES
      var parameters = QueryString.parse(contents);
      var accessToken = parameters['access_token'];

      // Try to gather the user info.
      return http.read('https://graph.facebook.com/me?access_token=$accessToken');
    }).then((String userInfo) {
      Map userData = JSON.decode(userInfo);
      print('---');
      print(userData);
      print('---');

      var user = new UserModel()
        ..username = userData['username'] != null ? userData['username'] : userData['id']
        ..facebookId = userData['id']
        ..firstName = userData['first_name']
        ..lastName = userData['last_name']
        ..email = userData['email']
        ..location = userData['location'] != null ? userData['location']['name'] : null;

      // TODO: We should have a real ID. Maybe we should generate one ourselves? Or just wait until we have a 'real' db.
      return Firebase.put('/users/${user.facebookId}.json', user.encode()).then((_) {
        // Save the user to the session.
        request.session['facebookId'] = user.facebookId;

        // Redirect.
        request.response.statusCode = 302;
        request.response.headers.add(HttpHeaders.LOCATION, '/');
      });
    });
  }
}
