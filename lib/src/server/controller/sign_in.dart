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
import 'package:woven/src/server/session_manager.dart';

class SignInController {
  static facebook(App app, HttpRequest request) {
    var code = Uri.encodeComponent(request.uri.queryParameters['code']);
    var appId = Uri.encodeComponent(config['authentication']['facebook']['appId']);
    var appSecret = Uri.encodeComponent(config['authentication']['facebook']['appSecret']);
    var callbackUrl = Uri.encodeComponent(config['authentication']['facebook']['url']);

    var url = 'https://graph.facebook.com/oauth/access_token?client_id=$appId&redirect_uri=$callbackUrl&client_secret=$appSecret&code=$code';
    return http.read(url).then((String contents) {
      // The contents look like this: access_token=USER_ACCESS_TOKEN&expires=NUMBER_OF_SECONDS_UNTIL_TOKEN_EXPIRES
      var parameters = QueryString.parse(contents);
      var accessToken = parameters['access_token'];

      // Try to gather the user info.
      return http.read('https://graph.facebook.com/me?access_token=$accessToken&fields=picture,first_name,last_name,gender,birthday,email,location');
    }).then((String userInfo) {
      print("Facebook returned: $userInfo");

      Map facebookData = JSON.decode(userInfo);

      var facebookId = facebookData['id'];

      // Get the large picture.
      return app.profilePictureUtil.downloadFacebookProfilePicture(id: facebookId, user: facebookId).then((filename) {
        facebookData['picture'] = filename;

        return facebookData;
      });

    }).then((Map facebookData) {
      // Streamline some of this data so it's easier to work with later.
      facebookData['location'] = facebookData['location']['name'];
      facebookData['firstName'] = facebookData['first_name']; facebookData.remove("first_name");
      facebookData['lastName'] = facebookData['last_name']; facebookData.remove("last_name");
      var facebookId = facebookData['facebookId'] = facebookData['id']; facebookData.remove("id");

      var user = new UserModel()
        ..username = facebookData['facebookId']
        ..facebookId = facebookData['facebookId']
        ..firstName = facebookData['firstName']
        ..lastName = facebookData['lastName']
        ..email = facebookData['email']
        ..location = facebookData['location']
        ..gender = facebookData['gender']
        ..picture = facebookData['picture']
        ..disabled = true;

      // Save the user to the session.
      request.session['id'] = facebookId;
      // Save the session to a cookie, sent to the browser with the request.
      var sessionManager = new SessionManager();
      sessionManager.addSessionCookieToRequest(request, request.session);

      return findFacebookIndex(facebookId).then((Map userIndexData) {
        if (userIndexData == null) {
          // Store the Facebook ID in an index that references the associated username.
          Firebase.put('/facebook_index/$facebookId.json', {'username': '$facebookId'});

          // Store the user, and we can use the index to find it and set a different username later.
          Firebase.put('/users/$facebookId.json', user.encode());
        } else {
          // If we already know of this Facebook user, update with any new data.
          var username = userIndexData['username'];

          // Get the existing user's data so we can compare against it.
          Firebase.get('/users/$username.json').then((Map userData) {
            facebookData.forEach((k, v) {
              if (userData[k] == null) userData[k] = v;
            });
            return userData;
          }).then((userData) {
            Firebase.put('/users/$username.json', userData);
          });
        }

        // Redirect.
        request.response.statusCode = 302;
        request.response.headers.add(HttpHeaders.LOCATION, (userIndexData != null) ? '/' : '/welcome');
      });
    });
  }

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
}


