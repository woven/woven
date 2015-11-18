library shared.model.event;

import 'item.dart';

class EventModel implements Item {
  String id;
  String user;
  String usernameForDisplay;
  String type;
  DateTime createdDate = new DateTime.now().toUtc();
  DateTime updatedDate = new DateTime.now().toUtc();
  String subject;
  String body;
  String url;
  String uriPreviewId;
  DateTime startDateTime;
  int startDateTimePriority;

  Map toJson() {
    return {
      "user": user,
      "subject": subject,
      "type": type,
      "body": body,
      "createdDate": createdDate.toString(),
      "updatedDate": updatedDate.toString(),
      "url": url,
      "uriPreviewId": uriPreviewId,
      "startDateTime": startDateTime.toString(),
      "startDateTimePriority": startDateTimePriority
    };
  }

  static EventModel fromJson(Map data) {
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
