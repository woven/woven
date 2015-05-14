library model.post;

import 'item.dart';

class Post implements Item {
  String id;
  String user;
  DateTime createdDate = new DateTime.now().toUtc();
  DateTime updatedDate = new DateTime.now().toUtc();

  String type;
  String message; // The user's message.
  String subject; // The attached content's subject.
  String body;

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
