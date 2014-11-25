library event_model;

import 'item.dart';
import 'trait/time_span.dart';
import 'trait/link.dart';

class EventModel extends ItemModel with TimeSpan, Link {

  Map encode() {
    var data = super.encode();
    data['startDateTime'] = startDateTime.toString();
    data['url'] = url;
    return data;
  }

  // TODO: Can I eliminate/inherit some of this? Mirrors.
  static EventModel decode(Map data) {
    return new EventModel()
      ..user = data['user']
      ..subject = data['subject']
      ..type = data['type']
      ..body = data['body']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate']

      ..startDateTime = data['startDateTime']
      ..url = data['url'];
  }
}