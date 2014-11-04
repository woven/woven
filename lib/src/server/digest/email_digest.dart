import 'package:mustache/mustache.dart' as mustache;
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../firebase.dart';
import '../../shared/input_formatter.dart';
import '../mailer/mailer.dart';
import '../../shared/response.dart';
import '../app.dart';

class EmailDigest {
  App app;

  EmailDigest(this.app);

  makeDigest() {
    List items = [];
    Map jsonForTemplate;

    var now = DateTime.parse("2014-11-04");
    var startOfToday = new DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    var endOfToday = new DateTime(now.year, now.month, now.day, 23, 59, 59, 999).millisecondsSinceEpoch;
    var query = '/items_by_community_by_type/miamitech/event.json?orderBy="startDateTimePriority"&startAt="$startOfToday"&endAt="$endOfToday"'; //&endAt="$endOfToday"
    print(query);

    Firebase.get(query).then((res) {
      Map itemsBlob = res;
      int count = 0;
      itemsBlob.forEach((k, v) {
        items.add(v);
        count++;
      });
      print("COUNT: $count");

      items.forEach((i) {
        String teaser = InputFormatter.createTeaser(i['body'], 400);
        i['body'] = teaser;
        i['startDateTime'] =  InputFormatter.formatDate(DateTime.parse(i['startDateTime']));
      });

      jsonForTemplate = {'items':items};
    }).catchError((e) => print("ERROR IS: $e\n======")).then((e) {
      new File('web/static/templates/daily_digest.mustache').readAsString().then((String contents) {
        // Parse the template.
        var template = mustache.parse(contents);
        var output = template.renderString(jsonForTemplate);

        // Output to an HTML file.
        new File('web/static/templates/daily_digest.html').writeAsString(output);

        return;
        // Send the welcome email.
        var envelope = new Envelope()
          ..from = "Woven <hello@woven.co>"
          ..to = "David Notik <hello@woven.co>"
          ..bcc = "David Notik <ddd@kaaks.com>"
          ..subject = 'Some awesome news from Woven 5'
          ..html = '$output';

        app.mailer.send(envelope).then((success) {
          print(success);
        });
      });
    });
  }
}