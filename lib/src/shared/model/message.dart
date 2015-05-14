library shared.model.message;

import 'package:observe/observe.dart';

import 'item.dart';

class Message extends Observable implements Item {
  @observable String id;
  @observable String user;
  @observable String usernameForDisplay;
  @observable DateTime createdDate = new DateTime.now().toUtc();
  @observable DateTime updatedDate = new DateTime.now().toUtc();

  @observable String type; // The type of message could be "notification" for example.
  @observable String message; // The user's message.
  @observable Map data; // Any extra data we might need to parse the message.
  @observable String community;

  Message();

  Map toJson() {
    return {
      "id": id,
      "user": user,
      "message": message,
      "type": type,
      "data": data,
      "community": community,
      "createdDate": createdDate.toString(),
      "updatedDate": updatedDate.toString(),
      "usernameForDisplay": usernameForDisplay
    };
  }

  Message.fromJson(Map json) {
    id = json['id'];
    user = json['user'];
    message = json['message'];
    type = json['type'];
    data = json['data'];
    community = json['community'];
    createdDate = (json['createdDate'] != null ? DateTime.parse(json['createdDate']) : null);
    updatedDate = (json['updatedDate'] != null ? DateTime.parse(json['updatedDate']) : null);
    usernameForDisplay = json['usernameForDisplay'];
  }
}
