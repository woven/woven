import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:convert';
import 'package:woven/src/client/app.dart';
import 'package:paper_elements/paper_autogrow_textarea.dart';
import 'package:core_elements/core_a11y_keys.dart';
import 'package:woven/config/config.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/src/client/components/chat_view/chat_view.dart';
import 'package:woven/src/client/view_model/chat.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';


@CustomTag('chat-box')
class ChatBox extends PolymerElement {
  @published App app;
  @published ChatViewModel viewModel;

  ChatBox.created() : super.created();

  final f = new db.Firebase(config['datastore']['firebaseLocation']);

  TextAreaElement get textarea => this.shadowRoot.querySelector('#comment-textarea');

  ChatView get chatView => document.querySelector('woven-app').shadowRoot.querySelector('chat-view');

  /**
   * Handle focus of the comment input.
   */
  onFocusHandler(Event e, detail, Element target) {
    CoreA11yKeys a11y = this.shadowRoot.querySelector('#a11y-send');
    a11y.target = this.shadowRoot.querySelector('#comment-textarea');
    this.shadowRoot.querySelector('#message-box').style.border = 'solid 1px rgb(39, 178, 1)';
  }

  onBlurHandler(Event e, detail, Element target) {
    this.shadowRoot.querySelector('#message-box').style.border = 'solid 1px #e6e6e6';
  }

  resetCommentInput() {
    PaperAutogrowTextarea commentInput = this.shadowRoot.querySelector('#comment');
    TextAreaElement textarea = this.shadowRoot.querySelector('#comment-textarea');
    textarea.value = "";
    textarea.focus();
    commentInput.update();
  }

  /**
   * Add the activity, in this case a comment.
   */
  addComment(Event e, var detail, Element target) {
    e.preventDefault();

//    new Timer(new Duration(milliseconds: 500), () {
//      chatViewEl.scroller.scrollTop = chatViewEl.scroller.scrollHeight + 1000;
//    });

//    print(chatViewEl.scroller.scrollHeight);

    TextAreaElement textarea = this.shadowRoot.querySelector('#comment-textarea');
    String message = textarea.value;
    if (message.trim() == "") {
//      window.alert("Your comment is empty.");
      resetCommentInput();
      return;
    }

    var communityId = app.community.alias;

    DateTime now = new DateTime.now().toUtc();

    // Save the message.
    var commentJson =  {'user': app.user.username, 'message': message, 'createdDate': now.toString(), 'community': communityId};
    Map messageMap = new Map.from(commentJson);

    // Insert the message instantly.
    // TODO: Figure out how to dismiss it client side.
    viewModel.insertMessage(messageMap);
    chatView.scrollToBottom();

    // Save the message to Firebase server-side.
    HttpRequest.request(
        Routes.addMessage.toString(),
        method: 'POST',
        sendData: JSON.encode(commentJson))
    .then((HttpRequest res) {
      // Set up the response as an object.
      var response = Response.fromJson(JSON.decode(res.responseText));
      var messageId = response.data;
      // TODO: Handle response.success true/false later.

      // Update details on the community.
      var parent = f.child('/communities/$communityId');

      parent.child('message_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          return 1;
        } else {
          return currentCount + 1;
        }
      });

//      print(messageId);

      // TODO: Handle notifications for chat messages.
//    HttpRequest.request(Routes.sendNotifications.toString() + "?itemid=$itemId&commentid=$messageId");
    });



    // Reset the fields.
    resetCommentInput();
  }

  signInWithFacebook() {
    app.signInWithFacebook();
  }
}
