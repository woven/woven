library shared.model.news;

import 'item.dart';
import '../util.dart';

class NewsModel implements Item {
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
  String feedId;

  Map toJson() {
    return {
      "user": user,
      "subject": subject,
      "type": type,
      "priority": priority,
      "body": body,
      "createdDate": encode(createdDate),
      "updatedDate": encode(updatedDate),
      "url": url,
      "uriPreviewId": uriPreviewId,
      "feedId": feedId
    };
  }

  static NewsModel fromJson(Map data) {
    return new NewsModel()
      ..user = data['user']
      ..type = data['type']
      ..priority = data['priority']
      ..subject = data['subject']
      ..body = data['body']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate']
      ..url = data['url']
      ..uriPreviewId = data['uriPreviewId']
      ..feedId = data['feedId'];
  }
}
