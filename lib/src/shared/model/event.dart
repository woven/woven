library event_model;

import 'item.dart';

class EventModel extends ItemModel {
  DateTime startDate;
  DateTime startTime;

  Map encode() {
    var data = super.encode();
    data['startDate'] = startDate.toString();
    data['startTime'] = startTime.toString();
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

      ..startDate = data['startDate']
      ..startTime = data['startTime'];
    ;
  }
}