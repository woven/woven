library item_model;

class ItemModel {
  String id;
  String user;
  String message; // The user's message.
  String subject; // The attached content's subject.
  String type;
  String body;
  DateTime createdDate = new DateTime.now().toUtc();
  DateTime updatedDate = new DateTime.now().toUtc();

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

  static ItemModel decode(Map data) {
    return new ItemModel()
      ..user = data['user']
      ..message = data['message']
      ..subject = data['subject']
      ..type = data['type']
      ..body = data['body']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate'];
  }
}
