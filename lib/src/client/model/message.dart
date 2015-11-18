library client.model.message;

import 'dart:convert';

import 'package:observe/observe.dart';
import 'package:firebase/firebase.dart';

import 'package:woven/src/shared/model/message.dart' as shared;

class Message extends shared.Message with Observable {
  @observable bool isHighlighted = false;
  @observable int priority;

  Message();

  /**
   * Add a message from the current user.
   * TODO: Consider adding messages from Woven and bots later.
   */
  static add(Message message, Firebase f) {
    var priority = new DateTime.now().toUtc().millisecondsSinceEpoch;
    var messagesRef = f.child('/messages').push();
    var messagesByCommunityRef = f.child('/messages_by_community/${message.community}/${messagesRef.key}');
    messagesRef.setWithPriority(message.toJson(), -priority);
    messagesByCommunityRef.setWithPriority(message.toJson(), -priority);
  }

  Message.fromJson(Map data) : super.fromJson(data) {
    priority = data['.priority'];
  }
}