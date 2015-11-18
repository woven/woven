library shared.model.event;

import 'item.dart';

class EventModel implements Item {
  String id;
  String user;
  String usernameForDisplay;
  String type;
  int priority;
  DateTime createdDate = new DateTime.now().toUtc();
  DateTime updatedDate = new DateTime.now().toUtc();
  String subject;
  String body;
  String url;
  String uriPreviewId;
  DateTime startDateTime;

  Map toJson() {
    return {
      "user": user,
      "subject": subject,
      "type": type,
      "priority": priority,
      "body": body,
      "createdDate": createdDate.toString(),
      "updatedDate": updatedDate.toString(),
      "url": url,
      "uriPreviewId": uriPreviewId,
      "startDateTime": startDateTime.toString()

    };
  }

  static EventModel fromJson(Map data) {
    return new EventModel()
      ..user = data['user']
      ..subject = data['subject']
      ..type = data['type']
      ..priority = data['priority']
      ..body = data['body']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate']
      ..startDateTime = data['startDateTime']
      ..url = data['url']
      ..uriPreviewId = data['uriPreviewId'];
  }
}
