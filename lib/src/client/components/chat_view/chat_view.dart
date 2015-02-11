import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/client/uri_policy.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'package:paper_elements/paper_autogrow_textarea.dart';
import 'package:core_elements/core_a11y_keys.dart';


@CustomTag('chat-view')
class ChatView extends PolymerElement {
  @published App app;
  @observable List messages = toObservable([]);

  final f = new db.Firebase(config['datastore']['firebaseLocation']);

    NodeValidator get nodeValidator => new NodeValidatorBuilder()
    ..allowHtml5(uriPolicy: new ItemUrlPolicy());

  String formatItemDate(DateTime value) => InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);

  Element get elRoot => document.querySelector('woven-app').shadowRoot.querySelector('chat-view');

  TextAreaElement get textarea => elRoot.shadowRoot.querySelector('#comment-textarea');

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

  /**
   * Handle focus of the comment input.
   */
  onFocusHandler(Event e, detail, Element target) {
//    elRoot.shadowRoot.querySelector("#footer").style.display = "block";
//    elRoot.shadowRoot.querySelector("#comment-message").style.opacity = "1";

    CoreA11yKeys a11y = elRoot.shadowRoot.querySelector('#a11y-send');
    a11y.target = elRoot.shadowRoot.querySelector('#comment-textarea');
  }

  onBlurHandler(Event e, detail, Element target) {
    //
  }

  resetCommentInput() {
    PaperAutogrowTextarea commentInput = elRoot.shadowRoot.querySelector('#comment');
    TextAreaElement textarea = elRoot.shadowRoot.querySelector('#comment-textarea');
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

    TextAreaElement textarea = elRoot.shadowRoot.querySelector('#comment-textarea');
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

  ChatView.created() : super.created();
}
