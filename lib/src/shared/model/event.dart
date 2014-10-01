library event_model;

import 'item.dart';

class EventModel extends ItemModel {
  DateTime startDateTime;

  Map encode() {
    var data = super.encode();
    data['startDateTime'] = startDateTime.toString();
    return data;
  }

  // TODO: Can I eliminate/inherit some of this?
  static EventModel decode(Map data) {
    return new EventModel()
      ..user = data['user']
      ..subject = data['subject']
      ..type = data['type']
      ..body = data['body']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate']

      ..startDateTime = data['startDateTime'];
  }
}