library item_model;

class ItemModel {
  String id;
  String user;
  String subject;
  String type;
  String body;
  String createdDate;
  String updatedDate;

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
