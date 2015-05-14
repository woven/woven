library event_model;

import 'post.dart';
import 'trait/time_span.dart';
import 'trait/link.dart';

class EventModel extends Post with TimeSpan, Link {

  Map encode() {
    var data = super.encode();
    data['startDateTime'] = startDateTime.toString();
    data['startDateTimePriority'] = startDateTimePriority.toString();
    data['url'] = url;
    data['uriPreviewId'] = uriPreviewId;
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
      ..startDateTimePriority = data['startDateTimePriority']
      ..url = data['url']
      ..uriPreviewId = data['uriPreviewId'];
  }
}