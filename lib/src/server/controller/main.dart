library main_controller;

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../app.dart';
import '../firebase.dart';
import '../../shared/response.dart';
import '../../shared/model/user.dart';
import '../../../config/config.dart';
import 'package:mailer/mailer.dart';

class MainController {
  static serveApp(App app, HttpRequest request, [String path]) {
    return new File(config['server']['directory'] + '/index.html');
  }

  static showCommunity(App app, HttpRequest request, String community) {
    if (Uri.parse(community).pathSegments[0].length > 0) {
      community = Uri.parse(community).pathSegments[0];
      Firebase.get('/alias_index/$community.json').then((indexData) {
        if (indexData == null) {
          return;
        } else {
          var type = indexData['type'];
        }
      });
    }

    // If you return an instance of File, it will be served.
    return new File(config['server']['directory'] + '/index.html');
  }

  static showItem(App app, HttpRequest request, String item) {
    // Serve the app as usual, and client router will handle showing the item.
    return new File(config['server']['directory'] + '/index.html');
  }

  static getCurrentUser(App app, HttpRequest request) {
    var id = request.cookies.firstWhere((cookie) => cookie.name == 'session').value;

    if (id == null) return new Response(false);

    // Find the username associated with the Facebook ID
    // that's in session.id, then get that user data.
    return Firebase.get('/facebook_index/$id.json').then((indexData) {
      var username = indexData['username'];
      return Firebase.get('/users/$username.json').then((userData) {
        Future send = sendEmail(app, userData, request);
        return new Response()
          ..data = userData;
      });
    });
  }

  static sendEmail(App app, Map user, HttpRequest request) {;
    // Test emailing.
    var envelope = new Envelope()
      ..from = 'support@woven.org'
      ..fromName = 'Woven'
      ..recipients.addAll(['davenotik@gmail.com'])
      ..subject = '${user['email']} just signed in!'
      ..text = '''
Username:   ${user['username']}
Name:       ${user['firstName']} ${user['lastName']}
Email:      ${user['email']}
Location:   ${user['location']}
Timestamp:  ${new DateTime.now()}

More:
${request.headers}
''';

    app.mailer.send(envelope);
    // End test emailing.
  }

  static aliasExists(String alias) {
    Firebase.get('/alias_index/$alias.json').then((res) {
      return (res == null ? false : true);
    });
  }
}
