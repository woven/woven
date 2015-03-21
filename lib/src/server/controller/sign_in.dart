library sign_in_controller;

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

class SignInController {
  static getCurrentUser(App app, HttpRequest request) {
    var sessionCookie = request.cookies.firstWhere((cookie) => cookie.name == 'session', orElse: () => null);
    if (sessionCookie == null) return Response.fromError('No session cookie found.');
    if (sessionCookie.value == null) return Response.fromError('The id in the session cookie was null.');

    var sessionId = sessionCookie.value;

    Future findUser(String username) => Firebase.get('/users/$username.json');
    Future findSession(String sessionId) => Firebase.get('/session_index/$sessionId.json');
    Future findUsernameFromSession(String sessionId) => Firebase.get('/session_index/$sessionId/username.json');
    Future findUsernameFromFacebookIndex(String facebookId) => Firebase.get('/facebook_index/$facebookId/username.json');

    // Check the session index for the user associated with this session id.
    return findSession(sessionId).then((Map sessionData) {
      if (sessionData == null) {
        // The user may have an old cookie, with Facebook ID, so let's check that index.
        return findUsernameFromFacebookIndex(sessionId).then((String username) {
          if (username == null) return null;
          // Update the old cookie to use a newer session ID, and add it to our session index.
          var newSessionId = app.sessionManager.createSessionId();
          app.sessionManager.addSessionCookieToRequest(request, newSessionId);
          app.sessionManager.addSessionToIndex(newSessionId, username.toLowerCase()).then((Map sessionData) {
            return sessionData;
          });
        });
      }
      return sessionData;
    }).then((Map sessionData) {
      if (sessionData == null) return Response.fromError('A session with that id was not found.');

      String authToken = sessionData['authToken'];
      String username = (sessionData['username'] as String).toLowerCase();

      // If the session has no auth token, just generate a new session.
      if (sessionData['authToken'] == null) {
        var newSessionId = app.sessionManager.createSessionId();
        app.sessionManager.addSessionCookieToRequest(request, newSessionId);
        app.sessionManager.addSessionToIndex(newSessionId, username).then((Map sessionData) {
          authToken = sessionData['authToken'];
        });
      }

      // Return the user data.
      return findUser(username).then((Map userData) {
        if (userData['password'] == null) userData['needsPassword'] = true;
        userData.remove('password');

        var response = new Response();

        if (authToken == null) {
          var newSessionId = app.sessionManager.createSessionId();
          app.sessionManager.addSessionCookieToRequest(request, newSessionId);
          return app.sessionManager.addSessionToIndex(newSessionId, username).then((Map sessionData) {
            userData['auth_token'] = sessionData['authToken'];
            response.data = userData;
            return response;
          });
        } else {
          userData['auth_token'] = authToken;
          response.data = userData;
          return response;
        }
      });
    });
  }

  static signOut(App app, HttpRequest request) => app.sessionManager.deleteCookie(request);

  static signIn(App app, HttpRequest request) {
    HttpResponse response = request.response;
    String dataReceived;

    // Check for a session cookie in the request.
    var sessionCookie = request.cookies.firstWhere((cookie) => cookie.name == 'session', orElse: () => null);

    // If there's an existing session cookie, use it. Else, create a new session id.
    String sessionId = (sessionCookie == null || sessionCookie.value == null) ? app.sessionManager.createSessionId() : sessionCookie.value;

    // Save the session to a cookie, sent to the browser with the request.
    app.sessionManager.addSessionCookieToRequest(request, sessionId);

    return request.listen((List<int> buffer) {
      dataReceived = new String.fromCharCodes(buffer);
    }).asFuture().then((_) {
      Map data = JSON.decode(dataReceived);
      String username = (data['username'] as String).toLowerCase();
      var password = data['password'];
      return checkCredentials(username, password).then((success) {
        if (!success) return Response.fromError('Bad credentials.');
        return app.sessionManager.addSessionToIndex(sessionId, username).then((sessionData) {
          return findUserInfo(username).then((Map userData) {
            var response = new Response();
            userData['authToken'] = sessionData['authToken'];
            userData.remove('password');
            response.data = userData;
            response.success = true;
            return response;
          });
        });

      });
    });
  }

  static Future<bool> checkCredentials(String username, String password) {
    String hashedPassword = hash(password);
    return Firebase.get('/users/$username/password.json').then((res) {
      if (res == null) return false;
      return res == hashedPassword;
    });
  }

  static Future findUserInfo(String username) => Firebase.get('/users/$username.json');

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
      Map facebookData = JSON.decode(userInfo);

      var facebookId = facebookData['id'];

      // Get the profile pictures.
      return app.profilePictureUtil.downloadFacebookProfilePicture(id: facebookId, user: facebookId).then((Response res) {
        Map pictures = res.data;

        facebookData['picture'] = pictures['original'];
        facebookData['pictureSmall'] = pictures['small'];

        return facebookData;
      });

    }).then((Map facebookData) {
      // Streamline some of this data so it's easier to work with later.
      facebookData['location'] = facebookData['location'] != null ? facebookData['location']['name'] : null;
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
        ..pictureSmall = facebookData['pictureSmall']
        ..disabled = true;

      // Check for a session cookie in the request.
      var sessionCookie = request.cookies.firstWhere((cookie) => cookie.name == 'session', orElse: () => null);

      // If there's an existing session cookie, use it. Else, create a new session id.
      String sessionId = (sessionCookie == null || sessionCookie.value == null) ? app.sessionManager.createSessionId() : sessionCookie.value;

      return findFacebookIndex(facebookId).then((Map facebookIndexData) {
        // Upon sign in with Facebook, we redirect as appropriate.
        request.response.statusCode = 302;
        request.response.headers.add(HttpHeaders.LOCATION, '/');

        if (facebookIndexData == null) {
          // Add the session to our index, and add a session cookie to the request.
          app.sessionManager.addSessionToIndex(sessionId, facebookId).then((sessionData) {
            // Store the Facebook ID in an index that references the associated username.
            Firebase.put('/facebook_index/$facebookId.json', {'username': '$facebookId'}, auth: sessionData['authToken']);

            // Store the user, and we can use the index to find it and set a different username later.
            Firebase.put('/users/$facebookId.json', user.toJson(), auth: sessionData['authToken']);

            app.sessionManager.addSessionCookieToRequest(request, sessionId);
          });
        } else {
          // If we already know of this Facebook user, update with any new data.
          var username = facebookIndexData['username'];

          // Get the existing user's data so we can compare against it.
          // TODO: Handle edge case where index points to non-existent user.
          return Firebase.get('/users/$username.json').then((Map userData) {
            if (userData == null) return null;
            facebookData.forEach((k, v) {
              if (userData[k] == null) userData[k] = v;
            });
            return userData;
          }).then((userData) {
            // TODO: handle null.
            // Update the session index with a reference to this username.
            app.sessionManager.addSessionToIndex(sessionId, username).then((sessionData) {
              Firebase.patch('/users/$username.json', userData, auth: sessionData['authToken']);
              app.sessionManager.addSessionCookieToRequest(request, sessionId);
            });
          });
        }
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


