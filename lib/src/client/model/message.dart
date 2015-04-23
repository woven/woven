library message_model_client;

import 'package:woven/src/shared/model/message.dart' as shared;
import 'dart:convert';
import 'package:firebase/firebase.dart';

class MessageModel extends shared.MessageModel {
  /**
   * Add a message from the current user.
   * TODO: Consider adding messages from Woven and bots later.
   */
  static add(MessageModel message, Firebase f) {
    var priority = new DateTime.now().toUtc().millisecondsSinceEpoch;
    var messagesRef = f.child('/messages').push();
    var messagesByCommunityRef = f.child('/messages_by_community/${message.community}/${messagesRef.key}');
    messagesRef.setWithPriority(message.toJson(), -priority);
    messagesByCommunityRef.setWithPriority(message.toJson(), -priority);
  }
}