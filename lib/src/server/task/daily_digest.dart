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
  DateTime runAtDailyTime = new DateTime.utc(1900, 1, 1, 12, 00); // Equivalent to 7am EST.

  DailyDigestTask();

  /**
   * Runs the task.
   */
  Future run() {
    DateTime now = new DateTime.now().toUtc();
    print("Starting daily digest task at $now...");
    return CommunityModel.getCommunitiesWithUsers().then((List<Map> usersByCommunity) {
      // Loop over each community/users map.
      usersByCommunity.forEach((Map communitiesWithUsers) {
        CommunityModel community = communitiesWithUsers['community'];
        List<UserModel> users = communitiesWithUsers['users'];

        if (users == null) return;

        // Hardcode EST (UTC-5) for now.
        DateTime startOfDay = new DateTime.utc(now.year, now.month, now.day).add(new Duration(hours:5));
        DateTime endOfDay = startOfDay.add(new Duration(hours: 23, minutes: 59, seconds: 59));
//        print("startOf: $startOfDay, endOf: $endOfDay");

        generateDigest(community.alias, from: startOfDay, to: endOfDay).then((String output) {
          // If the digest returned nothing, we're done here.
          if (output == null) return;
          // Send the digest to each user in the community.
          users.forEach((user) {
            if (user == null) return;
            if (user.username != 'dave') return; // TODO: Temporarily limited to Dave.

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
              ..subject = 'Here\'s the ${community.alias} digest, ${user.firstName} – ${now.toString()}'
              ..html = '$mergedDigest';

            app.mailer.send(envelope).then((Map res) {
              if (res['status'] == 200) return; // Success.
              print('Daily digest failed to send. Response was:\n$res');
            });
          });
        }).catchError((e, s) => print("Exception caught generating and sending digest:\n$e\n\n$s"));
      });
    });
  }

  /**
   * Generate the HTML output for the daily digest.
   */
  Future generateDigest(String community, {DateTime from, DateTime to}) {
    Map jsonForTemplate;
    List events = [];
    List news = [];

    DateTime now = new DateTime.now().toUtc();
    DateTime yesterday = now.subtract(new Duration(days: 1));

    Future<List> findEvents() {
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

      return Firebase.get(query).then((Map itemsMap) {
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
          i['body'] = teaser;
          i['startDateTime'] = InputFormatter.formatDate(startDateTime);
          i['encodedId'] = hashEncode(i['id']);
        });

        return events;
      });
    }

    Future<List> findNews() {
      var startAt = new DateTime.utc(yesterday.year, yesterday.month, yesterday.day, 12, 00, 00);
      var endAt = new DateTime.utc(now.year, now.month, now.day, 23, 59, 00); // TODO: Set back to 12 UTC.
      var query = '/items_by_community_by_type/$community/news.json?orderBy="createdDate"&startAt="$startAt"&endAt="$endAt"';

      return Firebase.get(query).then((Map itemsMap) {
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
          i['body'] = teaser;
          i['createdDate'] = InputFormatter.formatDate(createdDate);
          i['encodedId'] = hashEncode(i['id']);
        });

        return news;
      });
    }

    return Future.wait([findEvents(), findNews()]).then((_) {
      jsonForTemplate = {
          'events': events,
          'news': news
      };
    }).then((_) {
      if (jsonForTemplate == null) return null;

      return new File('web/static/templates/daily_digest.mustache').readAsString().then((String contents) {
        // Parse the template.
        var template = mustache.parse(contents);
        var output = template.renderString(jsonForTemplate);

        return output;
      });
    });
  }
}
