import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:firebase/firebase.dart' as db;

import 'package:woven/src/client/uri_policy.dart';
import 'package:woven/src/client/components/chat_view/chat_view.dart';

@CustomTag('chat-list')
class ChatList extends PolymerElement {
  @published App app;
  @observable List messages = toObservable([]);

  final f = new db.Firebase(config['datastore']['firebaseLocation']);

    NodeValidator get nodeValidator => new NodeValidatorBuilder()
    ..allowHtml5(uriPolicy: new ItemUrlPolicy());

  String formatItemDate(DateTime value) => InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);

  Element get elRoot => document.querySelector('woven-app').shadowRoot.querySelector('chat-list');

  ChatView get chatViewEl => document.querySelector('woven-app').shadowRoot.querySelector('chat-view');

  /**
   * Get the activities for this item.
   */
  getMessages() {
    var communityId;

    if (app.community == null) {
      communityId = Uri.parse(window.location.toString()).pathSegments[0];
    } else {
      communityId = app.community.alias;
    }

    var messagesRef = f.child('/messages_by_community/$communityId');
    messagesRef.onChildAdded.listen((e) {
      var comment = e.snapshot.val();
      comment['createdDate'] = DateTime.parse(comment['createdDate']);
      comment['id'] = e.snapshot.name;

      f.child('/users/' + comment['user']).once('value').then((snapshot) {
        Map user = snapshot.val();
        if (user == null) return;
        if (user['picture'] != null) {
          comment['user_picture'] = "${config['google']['cloudStoragePath']}/${user['picture']}";
        } else {
          comment['user_picture'] = null;
        }
      }).then((e) {
        // Insert each new item at end of list so the list is descending.
        messages.insert(messages.length, comment);
//        messages.sort((m1, m2) => m1["createdDate"].compareTo(m2["createdDate"]));
        // TODO: Look into not scrolling if user has scrolled up.
        new Timer(new Duration(milliseconds: 50), () {
          chatViewEl.scroller.scrollTop = chatViewEl.scroller.scrollHeight;
        });
      });
    });

  }

  /**
   * Handle formatting of the comment text.
   *
   * Format line breaks, links, @mentions.
   */
  formatText(String text) {
    if (text.trim().isEmpty) return 'Loading...';
    String formattedText = InputFormatter.formatMentions(InputFormatter.nl2br(InputFormatter.linkify(text.trim())));
    return formattedText;
  }

  fixItemCommunities() {
      if (app.community != null) {
          // Update the community's copy of the item.
        f.child('/items/' + app.selectedItem['id'] + '/communities/' + app.community.alias)
          ..set(true);
      }
  }

  attached() {
    getMessages();
//    fixItemCommunities();
  }

  detached() {
    //
  }

  ChatList.created() : super.created();
}
