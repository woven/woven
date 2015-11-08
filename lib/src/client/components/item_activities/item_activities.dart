import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/client/uri_policy.dart';
import 'package:woven/src/shared/util.dart';
import 'package:woven/src/client/model/user.dart';

import 'package:paper_elements/paper_autogrow_textarea.dart';
import 'package:core_elements/core_a11y_keys.dart';


@CustomTag('item-activities')
class ItemActivities extends PolymerElement {
  @published App app;
  @observable List comments = toObservable([]);

  db.Firebase get f => app.f;

  //TODO: Further explore this ViewModel stuff.
  //@observable ActivityCommentModel activity = new ActivityCommentModel();

    NodeValidator get nodeValidator => new NodeValidatorBuilder()
    ..allowHtml5(uriPolicy: new ItemUrlPolicy());

  String formatItemDate(DateTime value) => InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);

  Element get elRoot => document.querySelector('woven-app').shadowRoot.querySelector('item-activities');

  TextAreaElement get textarea => elRoot.shadowRoot.querySelector('#comment-textarea');

  /**
   * Get the activities for this item.
   */
  getActivities() {
    var itemId;
    // If there's no app.selectedItem, we probably
    // came here directly, so let's use itemId from the URL.
    if (app.router.selectedItem == null) {
      // Decode the base64 URL and determine the item.
      var encodedItemId = Uri.parse(window.location.toString()).pathSegments[1];
      itemId = base64Decode(encodedItemId);
    } else {
      itemId = app.router.selectedItem['id'];
    }

    var commentsRef = f.child('/items/' + itemId + '/activities/comments');
    commentsRef.onChildAdded.listen((e) {
      var comment = e.snapshot.val();
      comment['createdDate'] = DateTime.parse(comment['createdDate']);
      comment['id'] = e.snapshot.key;

      // Make sure we're using the collapsed username.
      comment['user'] = (comment['user'] as String).toLowerCase();

      UserModel.usernameForDisplay(comment['user'], f, app.cache).then((String usernameForDisplay) {
        comment['usernameForDisplay'] = usernameForDisplay;

        // Insert each new item at top of list so the list is ascending.
        comments.insert(0, comment);
        comments.sort((m1, m2) => m1["createdDate"].compareTo(m2["createdDate"]));
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

    var itemId = app.router.selectedItem['id'];

    DateTime now = new DateTime.now().toUtc();

    // Save the comment
    var id = f.child('/items/' + itemId + '/activities/comments').push();
    var commentJson =  {'user': app.user.username.toLowerCase(), 'comment': comment, 'createdDate': '$now'};

    // Set the item in multiple places because denormalization equals speed.
    // We also want to be able to load the item when we don't know the community.
    Future setComment(db.Firebase commentRef) {
      commentRef.set(commentJson);
    }

    setComment(id);

    // Update some details on the parent item.
    var parent = f.child('/items/' + itemId);
    Future updateParentItem(db.Firebase parentRef) {
      parent.update({
        'updatedDate': '$now'
      }).then((e) {
        // Update the comment count on the parent.
        parent.child('comment_count').transaction((currentCount) {
          if (currentCount == null || currentCount == 0) {
            return 1;
          } else {
            return currentCount + 1;
          }
        });

        var type = '';

        // Get the item's type.
        parent.child('/type').once('value').then((snapshot) {
          type = snapshot.val();
        }).then((e) {
          // Determine the communities this item is in,
          // so we can be sure to update those copies too.
          parent.child('/communities').onValue.listen((e) {
            Map communitiesRef = e.snapshot.val();
            if (communitiesRef != null) {
              communitiesRef.keys.forEach((community) {
                // Because denormalization means speed, we update the copy of the item in multiple places.

                // Uodate the updated date.
                f.child('/items_by_community/' + community + '/' + itemId).update({
                    'updatedDate': '$now'
                });
                f.child('/items_by_community_by_type/' + community + '/$type/' + itemId).update({
                    'updatedDate': '$now'
                });

                // Uodate the comment count.
                f.child('/items_by_community/' + community + '/' + itemId + '/comment_count').transaction((currentCount) {
                  if (currentCount == null || currentCount == 0) {
                    return 1;
                  } else {
                    return currentCount + 1;
                  }
                });
                f.child('/items_by_community_by_type/' + community + '/$type/' + itemId + '/comment_count').transaction((currentCount) {
                  if (currentCount == null || currentCount == 0) {
                    return 1;
                  } else {
                    return currentCount + 1;
                  }
                });

                // Update the priority sorting of the item to reflect updated date.
                DateTime time = DateTime.parse("$now");
                var epochTime = time.millisecondsSinceEpoch;
                f.child('/items_by_community/' + community + '/' + itemId).setPriority(-epochTime);
                // We don't want to mess with the priority sort for events in items_by_community_by_type.
                if (type != 'event') {
                  f.child('/items_by_community_by_type/' + community + '/$type/' + itemId).setPriority(-epochTime);
                }

                f.child('/items/' + itemId).setPriority(-epochTime);

                // Update the community itself.
                f.child('/communities/' + community).update({
                    'updatedDate': '$now'
                });
              });
            }
          });
        });
      });
    }

    updateParentItem(parent);

    var commentId = id.key;
    // Send a notification email to the item's author.
    HttpRequest.request(app.serverPath + Routes.sendNotificationsForComment.toString() + "?id=$commentId&itemid=$itemId");

    // Reset the fields.
    resetCommentInput();
  }

  signInWithFacebook() {
    app.signInWithFacebook();
  }

  fixItemCommunities() {
      if (app.community != null) {
          // Update the community's copy of the item.
        f.child('/items/' + app.router.selectedItem['id'] + '/communities/' + app.community.alias)
          ..set(true);
      }
  }

  attached() {
    getActivities();
  }

  detached() {
    //
  }

  ItemActivities.created() : super.created();
}
