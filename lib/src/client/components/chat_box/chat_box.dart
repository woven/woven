import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/client/app.dart';
import 'package:paper_elements/paper_autogrow_textarea.dart';
import 'package:core_elements/core_a11y_keys.dart';
import 'package:woven/config/config.dart';
import 'package:firebase/firebase.dart' as db;


@CustomTag('chat-box')
class ChatBox extends PolymerElement {
  @published App app;

  ChatBox.created() : super.created();

  final f = new db.Firebase(config['datastore']['firebaseLocation']);

  TextAreaElement get textarea => this.shadowRoot.querySelector('#comment-textarea');

  /**
   * Handle focus of the comment input.
   */
  onFocusHandler(Event e, detail, Element target) {
    CoreA11yKeys a11y = this.shadowRoot.querySelector('#a11y-send');
    a11y.target = this.shadowRoot.querySelector('#comment-textarea');
  }

  onBlurHandler(Event e, detail, Element target) {
    //
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

    TextAreaElement textarea = this.shadowRoot.querySelector('#comment-textarea');
    String comment = textarea.value;
    if (comment.trim() == "") {
//      window.alert("Your comment is empty.");
      resetCommentInput();
      return;
    }

    var communityId = app.community.alias;

    DateTime now = new DateTime.now().toUtc();

    // Save the comment
    var id = f.child('/messages_by_community/${app.community.alias}').push();
    var commentJson =  {'user': app.user.username, 'comment': comment, 'createdDate': '$now'};

    // Set the item in multiple places because denormalization equals speed.
    // We also want to be able to load the item when we don't know the community.
    Future setComment(db.Firebase commentRef) {
      commentRef.set(commentJson);
    }

    setComment(id);

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
