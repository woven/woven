import 'dart:io';
import 'dart:math';

import 'package:intl/intl.dart';

import 'package:woven/src/server/task/daily_digest.dart';
import 'package:woven/src/server/mailer/mailer.dart';
import 'package:woven/src/server/model/community.dart';


main() {
  generateDigest(sendEmail: true);
}

/**
 * Generate the digest.
 */
generateDigest({sendEmail: false, community: 'miamitech'}) async {
  var digest = new DailyDigestTask();
  var output = await digest.generateDigest(community, from: new DateTime(2015, 05, 1, 0), to: new DateTime.now());

  var file = new File('/Users/dave/output/${community}_digest.html');

  file.writeAsString(output);

  if (sendEmail) {
    String communityName = await CommunityModel.getCommunityName(community);

    var mergedDigest = output;

    DateTime now = new DateTime.now();
    var formatter = new DateFormat('E M/d/yy');
    String formattedToday = formatter.format(now);

    var rnd = new Random();

    // Generate and send the email.
    var envelope = new Envelope()
      ..from = "Woven <hello@woven.co>"
      ..to = ['David Notik <davenotik@gmail.com>']
      ..subject = '$communityName – Today\'s activity – $formattedToday – ${rnd.nextInt(1000)}'
      ..html = '$mergedDigest';

    Map res = await Mailgun.send(envelope);
    if (res['status'] == 200) return;
    // Success.
    print('Daily digest failed to send. Response was:\n$res');
  }
}

emailDigest() async {

}