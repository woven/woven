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
  DateTime runAtDailyTime = new DateTime.utc(1900, 1, 1, 17, 10); // Equivalent to 7am EST.

  DailyDigestTask();

  /**
   * Runs the task.
   */
  Future run() async {
    DateTime now = new DateTime.now().toUtc();
    print("Starting daily digest task at $now...");
    List<Map> usersByCommunity = await CommunityModel.getCommunitiesWithUsers();

    // Loop over each community/users map.
    usersByCommunity.forEach((Map communitiesWithUsers) async {
      CommunityModel community = communitiesWithUsers['community'];
      List<UserModel> users = communitiesWithUsers['users'];

      if (users == null) return;

      // Hardcode EST (UTC-5) for now.
      DateTime startOfDay = new DateTime.utc(now.year, now.month, now.day).add(new Duration(hours:5));
      DateTime endOfDay = startOfDay.add(new Duration(hours: 23, minutes: 59, seconds: 59));
//        print("startOf: $startOfDay, endOf: $endOfDay");

      try {
        String output = await generateDigest(community.alias, from: startOfDay, to: endOfDay);

        // If the digest returned nothing, we're done here.
        if (output == null) return;
        // Send the digest to each user in the community.
        users.forEach((user) async {
          if (user == null) return;
          if (user.username != 'dave') return;
          // TODO: Temporarily limited to Dave.

          // Personalize the output using merge tokens.
          // We based our merge tokens off of MailChimp: http://goo.gl/xagsyk
          var mergedDigest = output
          .replaceAll(r'*|FNAME|*', user.firstName)
          .replaceAll(r'*|LNAME|*', user.lastName)
          .replaceAll(r'*|EMAIL|*', user.email);

          DateTime now = new DateTime.now();

          // Generate and send the email.
          var envelope = new Envelope()
            ..from = "Woven <hello@woven.co>"
            ..to = ['${user.firstName} ${user.lastName} <${user.email}>']
            ..subject = '[${community.alias}] Today\'s activity'
            ..html = '$mergedDigest';

          Map res = await Mailgun.send(envelope);
          if (res['status'] == 200) return;
          // Success.
          print('Daily digest failed to send. Response was:\n$res');

        });
      } catch(error, stack) {
        print("Exception caught generating and sending digest:\n$error\n\n$stack");
      }
    });
  }

  /**
   * Generate the HTML output for the daily digest.
   */
  Future generateDigest(String community, {DateTime from, DateTime to}) async {
    Map jsonForTemplate = {};
    List events = [];
    List news = [];

    String communityName = await CommunityModel.getCommunityName(community);

    DateTime now = new DateTime.now().toUtc();
    DateTime yesterday = now.subtract(new Duration(days: 1));

    Future<List> findEvents() async {
      // Handle empty to/from.
      if (from == null) {
        from = new DateTime.utc(now.year, now.month, now.day);
      }
      if (to == null) {
        to = new DateTime.utc(from.year, from.month, from.day, 23, 59, 59, 999);
      }

      var startAt = from.millisecondsSinceEpoch;
      var endAt = to.millisecondsSinceEpoch;
      var query = '/items_by_community_by_type/$community/event.json?orderBy="startDateTimePriority"&startAt="$startAt"&endAt="$endAt"';

      Map itemsMap = await Firebase.get(query);

      // If there are no items for the digest, get out of here.
      if (itemsMap.isEmpty) return null;

      itemsMap.forEach((k, v) {
        // Add the key, which is the item ID, the map as well.
        var itemMap = v;
        itemMap['id'] = k;
        events.add(itemMap);
      });

      // Do some pre-processing.
      events.forEach((i) {
        String teaser = InputFormatter.createTeaser(i['body'], 200);
        // Convert the UTC start date to EST (UTC-5) for the newsletter.
        // TODO: Later, consider more timezones.
        DateTime startDateTime = DateTime.parse(i['startDateTime']).subtract(new Duration(hours: 5));
        // TODO: Revisit this, it was causing exception as News don't have subjects now.
        if (i['subject'] == null) i['subject'] = '';
        i['body'] = teaser;
        i['startDateTime'] = InputFormatter.formatDate(startDateTime);
        i['encodedId'] = base64Encode(i['id']);
      });

      return events;
    }

    Future<List> findNews() async {
      var startAt = new DateTime.utc(yesterday.year, yesterday.month, yesterday.day, 12, 00, 00);
      var endAt = new DateTime.utc(now.year, now.month, now.day, 23, 59, 00); // TODO: Set back to 12 UTC.
      var query = '/items_by_community_by_type/$community/news.json?orderBy="createdDate"&startAt="$startAt"&endAt="$endAt"';

      Map itemsMap = await Firebase.get(query);

      if (itemsMap.isEmpty) return null;

      itemsMap.forEach((k, v) {
        // Add the key, which is the item ID, the map as well.
        var itemMap = v;
        itemMap['id'] = k;
        news.add(itemMap);
      });

      // Do some pre-processing.
      news.forEach((i) {
        String teaser = InputFormatter.createTeaser(i['body'], 200);

        // Convert the UTC start date to EST (UTC-5). TODO: Later, consider more timezones.
        DateTime createdDate = DateTime.parse(i['createdDate']).subtract(new Duration(hours: 5));

        // TODO: Revisit this, it was causing exception as News don't have subjects now.
        if (i['subject'] == null) i['subject'] = '';

        i['body'] = teaser;
        i['createdDate'] = InputFormatter.formatDate(createdDate);
        i['encodedId'] = base64Encode(i['id']);
      });

      return news;
    }

    await Future.wait([findEvents(), findNews()]);

    if (news.isEmpty && events.isEmpty) return null;

    jsonForTemplate['communityName'] = communityName;
    jsonForTemplate['community'] = community;
    jsonForTemplate['events'] = events;
    jsonForTemplate['news'] = news;

    String contents = await new File('web/static/templates/daily_digest.mustache').readAsString();

    // Parse the template.
    var template = mustache.parse(contents);
    var output = template.renderString(jsonForTemplate);

    return output;
  }
}
