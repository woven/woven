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
import 'package:woven/src/shared/model/message.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';

@CustomTag('chat-box')
class ChatBox extends PolymerElement {
  @published App app;
  @published ChatViewModel viewModel;

  List<StreamSubscription> subscriptions = [];

  ChatBox.created() : super.created();

  db.Firebase get f => app.f;

  TextAreaElement get textarea => this.shadowRoot.querySelector('#comment-textarea');

  ChatView get chatView => document.querySelector('woven-app').shadowRoot.querySelector('chat-view');

  /**
   * Handle focus of the comment input.
   */
  onFocusHandler(Event e, detail, Element target) {
    CoreA11yKeys a11y = this.shadowRoot.querySelector('#a11y-send');
    a11y.target = this.shadowRoot.querySelector('#comment-textarea');
    this.shadowRoot.querySelector('#message-box').classes.add('active');
  }

  onBlurHandler(Event e, detail, Element target) {
    this.shadowRoot.querySelector('#message-box').classes.remove('active');
  }

  resetCommentInput() {
    PaperAutogrowTextarea commentInput = this.shadowRoot.querySelector('#comment');
    textarea.value = "";
    textarea.focus();
    commentInput.update();
  }

  /**
   * Add the activity, in this case a comment.
   */
  addComment(Event e, var detail, Element target) {
    e.preventDefault();

    TextAreaElement textarea = this.shadowRoot.querySelector('#comment-textarea');
    String messageText = textarea.value;
    var communityId = app.community.alias;

    if (messageText.trim().isEmpty) {
      Timer.run(() => resetCommentInput());
      return;
    }

    var message = new MessageModel()
      ..message = messageText
      ..community = app.community.alias
      ..user = app.user.username.toLowerCase();

    // Handle commands.
    if (message.message.trim().startsWith(('/'))) {
      message.type = 'notification';
      viewModel.commandRouter(message);
      Timer.run(() => chatView.scrollToBottom());
      Timer.run(() => resetCommentInput());
    }

    // Insert the message instantly.
    Map messageMap = new Map.from(message.toJson());
    messageMap['usernameForDisplay'] = app.user.username;
    viewModel.insertMessage(messageMap);
    Timer.run(() => chatView.scrollToBottom());

    // Save the message to Firebase server-side.
    HttpRequest.request(
        Routes.addMessage.toString(),
        method: 'POST',
        sendData: JSON.encode({'model': message, 'authToken': app.authToken}))
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
    });

    // Reset the fields.
    Timer.run(() => resetCommentInput());
  }

  focusMessageInput() {
    PaperAutogrowTextarea commentInput = this.shadowRoot.querySelector('#comment');
    textarea.focus();
    commentInput.update();
  }

  attached() {
    // If we're signed in on attached, focus the message input.
    if (app.user != null && !app.isMobile) Timer.run(focusMessageInput);
    // If we later get signed in user, focus the message input.
    subscriptions.add(app.changes.listen((List<ChangeRecord> records) {
      PropertyChangeRecord record = records[0] as PropertyChangeRecord;
      if (record.name == new Symbol('user')) {
        if (app.user != null && !app.isMobile) Timer.run(focusMessageInput);
      }
    }));
  }

  detached() => subscriptions.forEach((subscription) => subscription.cancel());

  toggleSignIn() {
    app.toggleSignIn();
  }
}
