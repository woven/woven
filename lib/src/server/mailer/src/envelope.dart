library mailer.envelope;

import 'package:woven/src/shared/util.dart';

/**
 * This class represents an envelope that can be sent to someone/some people.
 */
class Envelope {
  String from = 'hello@woven.co';
  List to;
  List bcc;
  String subject;
  String text;
  String html;

  Map toMap() {
    return {
        'from': from,
        'to': to,
        'bcc': bcc,
        'subject': subject,
        'html': html,
        'text': text
    };
  }

  /**
   * Prepare the envelope for transmission over http POST.
   *
   * Removes null properties and converts lists to strings.
   */
  static prepareForPost(Envelope e) {
    Map map = e.toMap();
    Map newMap = new Map.from(map);
    map.forEach((k, v) {
      if (v is List) newMap[k] = (v as List).join(',');
    });
    return removeNullsFromMap(newMap);
  }
}
