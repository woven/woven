library admin_controller;

import 'package:shelf/shelf.dart' as shelf;

import '../app.dart';
import 'package:woven/src/server/task/daily_digest.dart';
import 'package:woven/src/shared/csv.dart';
import 'package:woven/src/server/firebase.dart';

class AdminController {
  /**
   * Format: admin/generatedigest?community=miamitech&from=2014-12-29T00:00:00-05:00&to=2014-12-29T23:59:59-05:00
   */
  static generateDigest(App app, shelf.Request request) async {
    var community = request.requestedUri.queryParameters['community'];
    var from = request.requestedUri.queryParameters['from'];
    var to = request.requestedUri.queryParameters['to'];

    try {
      // Parse the strings.
      if (from != null) from = DateTime.parse(from);
      if (to != null) to = DateTime.parse(to);
    } catch (error) {
      return "Error parsing those dates: $error";
    }

    // Generate a new daily digest.
    var digest = new DailyDigestTask();
    var digestOutput = await digest.generateDigest(community,
        from: from as DateTime, to: to as DateTime);

    shelf.Response response = new shelf.Response.ok(digestOutput,
        headers: {'content-type': 'text/html'});

    return response;
  }

  static exportUsers(App app, shelf.Request request) async {
//    TODO: Bring back export per community.
//      var id = request.uri.queryParameters['communityId'];

    Map usersMap = await Firebase.get('/users.json');
    List users = [];

    usersMap.values.forEach(users.add);

    var data = [
      ['Username', 'First name', 'Last name', 'Email']
    ];

    users.forEach((user) {
      data.add([
        user['username'],
        user['firstName'],
        user['lastName'],
        user['email']
      ]);
    });

    var headers = {
      'content-type': 'text/html',
      'Content-Disposition': 'attachment; filename="woven-users.csv"'
    };

    return new shelf.Response.ok(Csv.listToCsv(data), headers: headers);
  }
}
