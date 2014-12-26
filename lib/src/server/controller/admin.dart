library admin_controller;

import 'dart:io';
import 'dart:async';
import '../app.dart';
import 'package:woven/src/server/task/daily_digest.dart';
import 'package:woven/src/shared/csv.dart';
import 'package:woven/src/server/firebase.dart';

class AdminController {
  static generateDigest(App app, HttpRequest request) {
    var community = request.requestedUri.queryParameters['community'];
    var from = request.requestedUri.queryParameters['from'];
    var to = request.requestedUri.queryParameters['to'];

    try {
      // Parse the strings.
      if (from != null) from = DateTime.parse(from);
      if (to != null) to = DateTime.parse(to);
    } catch(error) {
      return "Error parsing those dates: $error";
    }

    // Generate a new daily digest.
    var digest = new DailyDigestTask();
    var digestOutput = digest.generateDigest(community, from: from as DateTime, to: to as DateTime);
    request.response.headers.contentType = ContentType.HTML;
    return digestOutput;
  }

  static exportUsers(App app, HttpRequest request) {
    createCsv(List users) {
      var data = [['Username', 'First name', 'Last name', 'Email']];

      users.forEach((user) {
        data.add([user['username'], user['firstName'], user['lastName'], user['email']]);
      });

      request.response.headers.add(HttpHeaders.CONTENT_TYPE, 'text/csv;charset=utf-8');
      request.response.headers.add('Content-Disposition', 'attachment; filename="woven-users.csv"');

      return Csv.listToCsv(data);
    }

    return new Future(() {
//    TODO: Bring back export per community.
//      var id = request.uri.queryParameters['communityId'];

      return Firebase.get('/users.json').then((res) {
        Map userBlob = res;
        List users = [];

        userBlob.forEach((k, v) {
          // Add the key, which is the item ID, the map as well.
          var userMap = v;
          users.add(userMap);
        });

        return createCsv(users);
      });
    });
  }
}