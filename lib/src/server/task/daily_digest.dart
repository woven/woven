library daily_digest_task;

import 'dart:async';
import 'dart:io';

import 'package:mustache/mustache.dart' as mustache;

import 'package:woven/src/server/firebase.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'task.dart';
import 'package:woven/src/shared/model/user.dart';
import '../model/community.dart';
import '../mailer/mailer.dart';

class DailyDigestTask extends Task {
  bool runImmediately = false;
  DateTime runAtDailyTime = parseTime('10:11pm');

  DailyDigestTask();

  /**
   * Runs the task.
   */
  Future run() {
    // Get a list of maps
    return CommunityModel.getCommunityUsers().then((List<Map> usersByCommunity) {
      // Loop over each community/users map.
      usersByCommunity.forEach((Map communityUsers) {
        CommunityModel community = communityUsers['community'];
        List<UserModel> users = communityUsers['users'];
        // Generate the community's digest.
        generateDigest(community.alias).then((String output) {
          sendDigestByEmail(output);
          // Send the digest to each user in the community.
//          users.forEach((user) {
//            // Personalize the output using merge tokens.
//            // We based our merge tokens off of MailChimp: http://goo.gl/xagsyk
//            var mergedDigest = output
//              .replaceAll(r'*|FNAME|*', user.firstName)
//              .replaceAll(r'*|LNAME|*', user.lastName)
//              .replaceAll(r'*|EMAIL|*', user.email);
//          });
        });
      });
    });
  }

  /**
   * Generate the HTML output for the daily digest.
   */
  Future generateDigest(String community, {DateTime from, DateTime to}) {
    List items = [];
    Map jsonForTemplate;

    if (from == null) from = new DateTime.now().toUtc();
    if (to == null) to = from;

    // Start at the beginning of the from date's day.
    var startAt = new DateTime(from.year, from.month, from.day).millisecondsSinceEpoch;

    // End at the end of the to date's day.
    var endAt = new DateTime(to.year, to.month, to.day, 23, 59, 59, 999).millisecondsSinceEpoch;

    var query = '/items_by_community_by_type/$community/event.json?orderBy="startDateTimePriority"&startAt="$startAt"&endAt="$endAt"';

    return Firebase.get(query).then((res) {
      Map itemsBlob = res;
      int count = 0;
      itemsBlob.forEach((k, v) {
        // Add the key, which is the item ID, the map as well.
        var itemMap = v;
        itemMap['id'] = k;
        items.add(itemMap);
        count++;
      });

      items.forEach((i) {
        String teaser = InputFormatter.createTeaser(i['body'], 400);
        i['body'] = teaser;
        i['startDateTime'] = InputFormatter.formatDate(DateTime.parse(i['startDateTime']));
        i['encodedId'] = hashEncode(i['id']);
      });

      jsonForTemplate = {
          'items':items
      };
    }).catchError((e) => print("Firebase returned an error: $e")).then((e) {
      return new File('web/static/templates/daily_digest.mustache').readAsString().then((String contents) {
        // Parse the template.
        var template = mustache.parse(contents);
        var output = template.renderString(jsonForTemplate);

        return output;
      });
    });
  }

  Future sendDigestByEmail(String output) {
    var envelope = new Envelope()
      ..from = "Woven <hello@woven.co>"
      ..to = "David Notik <davenotik@gmail.com>"
      ..bcc = "David Notik <davenotik@gmail.com>"
      ..subject = 'Welcome, David!'
      ..html = '$output';
    return app.mailer.send(envelope).then((success) {
      print(success);
    });
  }
}
