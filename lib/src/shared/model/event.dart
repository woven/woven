library event_model;

import 'item.dart';

class EventModel extends ItemModel {

  Map encode() {
    return {
        "user": user,
        "subject": subject,
        "type": type,
        "body": body,
        "createdDate": createdDate,
        "updatedDate": updatedDate
    };
  }

  static ItemModel decode(Map data) {
    return new ItemModel()
      ..user = data['user']
      ..subject = data['subject']
      ..type = data['type']
      ..body = data['body']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate'];
  }
}