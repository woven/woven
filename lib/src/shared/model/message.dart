library message_model;

class MessageModel {
  String id;
  String user;
  String message; // The user's message.
  String type;
  String community;
  DateTime createdDate = new DateTime.now().toUtc();
  DateTime updatedDate = new DateTime.now().toUtc();

  MessageModel();

  Map toJson() {
    return {
        "user": user,
        "message": message,
        "type": type,
        "community": community,
        "createdDate": createdDate.toString(),
        "updatedDate": updatedDate.toString()
    };
  }

  static MessageModel fromJson(Map data) {
    if (data == null) return null;
    return new MessageModel()
      ..user = data['user']
      ..message = data['message']
      ..type = data['type']
      ..type = data['community']
      ..createdDate = data['createdDate']
      ..updatedDate = data['updatedDate'];
  }

//  static MessageModel fromMessage(String message, {String type, String username}) {
//    return new MessageModel()
//      ..message = message
//      ..type = type
//      ..user = username;
//  }
}
