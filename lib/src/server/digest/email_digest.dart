library email_digest;

import 'package:mustache/mustache.dart' as mustache;
import 'dart:io';
import 'package:woven/src/server/firebase.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/server/mailer/mailer.dart';
import '../app.dart';
import 'package:woven/src/shared/util.dart';


class EmailDigest {
  App app;

  EmailDigest(this.app);

  /**
   * Generate HTML for the daily digest.
   *
   * Format for dates is YYYY-MM-DD, e/g/ 2014-12-22.
   */
  generateDigest(String community, {DateTime from, DateTime to}) {
    List items = [];
    Map jsonForTemplate;

    if (from == null) from = new DateTime.now();
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
        i['startDateTime'] =  InputFormatter.formatDate(DateTime.parse(i['startDateTime']));
        i['encodedId'] = hashEncode(i['id']);
      });

      jsonForTemplate = {'items':items};
    }).catchError((e) => print("Firebase returned an error: $e")).then((e) {
      return new File('web/static/templates/daily_digest.mustache').readAsString().then((String contents) {
        // Parse the template.
        var template = mustache.parse(contents);
        var output = template.renderString(jsonForTemplate);

        return output;

        // Output to an HTML file.
//        new File('web/static/templates/daily_digest.html').writeAsString(output);

//        return;
        // Send the welcome email.
//        var envelope = new Envelope()
//          ..from = "Woven <hello@woven.co>"
//          ..to = "David Notik <hello@woven.co>"
//          ..bcc = "David Notik <ddd@kaaks.com>"
//          ..subject = 'Some awesome news from Woven 5'
//          ..html = '$output';
//
//        app.mailer.send(envelope).then((success) {
//          print(success);
//        });
      });
    });
  }
}