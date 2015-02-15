import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/client/app.dart';
import 'package:paper_elements/paper_autogrow_textarea.dart';
import 'package:core_elements/core_a11y_keys.dart';
import 'package:woven/config/config.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/src/client/components/chat_view/chat_view.dart';
import 'package:woven/src/client/view_model/chat.dart';


@CustomTag('chat-box')
class ChatBox extends PolymerElement {
  @published App app;
  @published ChatViewModel viewModel;

  ChatBox.created() : super.created();

  final f = new db.Firebase(config['datastore']['firebaseLocation']);

  TextAreaElement get textarea => this.shadowRoot.querySelector('#comment-textarea');

  ChatView get chatViewEl => document.querySelector('woven-app').shadowRoot.querySelector('chat-view');

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

  debugKeys() {
    print("Woooot!");
  }

  /**
   * Add the activity, in this case a comment.
   */
  addComment(Event e, var detail, Element target) {
    e.preventDefault();

//    new Timer(new Duration(milliseconds: 500), () {
//      chatViewEl.scroller.scrollTop = chatViewEl.scroller.scrollHeight + 1000;
//    });

    print(chatViewEl.scroller.scrollHeight);

    TextAreaElement textarea = this.shadowRoot.querySelector('#comment-textarea');
    String message = textarea.value;
    if (message.trim() == "") {
//      window.alert("Your comment is empty.");
      resetCommentInput();
      return;
    }

    var communityId = app.community.alias;

    DateTime now = new DateTime.now().toUtc();

    // Save the comment
    var id = f.child('/messages_by_community/${app.community.alias}').push();
    var commentJson =  {'user': app.user.username, 'message': message, 'createdDate': '$now'};

    // Set the item in multiple places because denormalization equals speed.
    // We also want to be able to load the item when we don't know the community.
    Future setMessage(db.Firebase commentRef) {
      var priority = now.millisecondsSinceEpoch;
      commentRef.setWithPriority(commentJson, -priority);
    }

    setMessage(id);

    // Update some details on the parent item.
    var parent = f.child('/communities/$communityId');
    Future updateParentItem(db.Firebase parentRef) {
      parent.update({
          'updatedDate': '$now'
      }).then((e) {
        // Update the comment count on the parent.
        parent.child('message_count').transaction((currentCount) {
          if (currentCount == null || currentCount == 0) {
            return 1;
          } else {
            return currentCount + 1;
          }
        });
      });
    }

    updateParentItem(parent);

    var commentId = id.name;
    // Send a notification email to the item's author.
//    HttpRequest.request(Routes.sendNotifications.toString() + "?itemid=$itemId&commentid=$commentId");

    // Reset the fields.
    resetCommentInput();
  }

  signInWithFacebook() {
    app.signInWithFacebook();
  }
}
