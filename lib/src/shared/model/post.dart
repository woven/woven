library model.post;

import 'item.dart';

// TODO: Consider killing, as we've been weaning off this.
class Post implements Item {
  String id;
  String user;
  String usernameForDisplay;
  DateTime createdDate = new DateTime.now().toUtc();
  DateTime updatedDate = new DateTime.now().toUtc();

  String type;
  int priority;
  String message; // The user's message.
  String subject; // The attached content's subject.
  String body;
  String feedId;

  Map encode() {
    return {
      "user": user,
      "message": message,
      "subject": subject,
      "type": type,
      "body": body,
      "createdDate": createdDate.toString(),
      "updatedDate": updatedDate.toString()
    };
  }

  static Post decode(Map data) {
    return new Post()
      ..user = data['user']
      ..message = data['message']
      ..subject = data['subject']
      ..type = data['type']
      ..body = data['body']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate'];
  }
}
