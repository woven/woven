import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/client/uri_policy.dart';

@CustomTag('item-activities')
class ItemActivities extends PolymerElement {
  @published App app;
  @observable List comments = toObservable([]);
  // We'll bind the form data to this.
  @observable Map theData = toObservable({});

  //TODO: Further explore this ViewModel stuff.
  //@observable ActivityCommentModel activity = new ActivityCommentModel();

    NodeValidator get nodeValidator => new NodeValidatorBuilder()
    ..allowHtml5(uriPolicy: new ItemUrlPolicy());

  var firebaseLocation = config['datastore']['firebaseLocation'];

  String formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  /**
   * Get the activities for this item.
   */
  getActivities() {
    var itemId;
    // If there's no app.selectedItem, we probably
    // came here directly, so let's use itemId from the URL.
    if (app.selectedItem == null) {
      // Decode the base64 URL and determine the item.
      var base64 = Uri.parse(window.location.toString()).pathSegments[1];
      var bytes = CryptoUtils.base64StringToBytes(base64);
      itemId = UTF8.decode(bytes);
    } else {
      itemId = app.selectedItem['id'];
    }

    var f = new db.Firebase(firebaseLocation + '/items/' + itemId + '/activities/comments');
    f.onChildAdded.listen((e) {
      var comment = e.snapshot.val();
      comment['createdDate'] = DateTime.parse(comment['createdDate']);
      comment['id'] = e.snapshot.name;

      // Insert each new item at top of list so the list is ascending.
      comments.insert(0, comment);
    });
  }

  formatText(String text) {
    if (text.trim().isEmpty) return 'Loading...';
    String formattedText = InputFormatter.nl2br(InputFormatter.linkify(text.trim()));
    return formattedText;
  }

  /**
   * Add the activity, in this case a comment.
   */
  addComment(Event e, var detail, Element target) {
    e.preventDefault();

    String comment = theData['comment'];
    comment = comment.trim();

    if (comment == "") {
      window.alert("Your comment is empty.");
      return false;
    }

    var itemId = app.selectedItem['id'];

    DateTime now = new DateTime.now().toUtc();

    // Save the comment
    var root = new db.Firebase(config['datastore']['firebaseLocation']);
    var id = root.child('/items/' + itemId + '/activities/comments').push();
    var commentJson =  {'user': app.user.username, 'comment': comment, 'createdDate': '$now'};

    // Set the item in multiple places because denormalization equals speed.
    // We also want to be able to load the item when we don't know the community.
    Future setComment(db.Firebase commentRef) {
      commentRef.set(commentJson);
    }

    setComment(id);

    // Update some details on the parent item.
    var parent = root.child('/items/' + itemId);
    Future updateParentItem(db.Firebase parentRef) {
      parent.update({
        'updatedDate': '$now'
      }).then((e) {
        // Update the comment count on the parent.
        parent.child('comment_count').transaction((currentCount) {
          if (currentCount == null || currentCount == 0) {
            return 0;
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
                root.child('/items_by_community/' + community + '/' + itemId).update({
                    'updatedDate': '$now'
                });
                root.child('/items_by_community_by_type/' + community + '/$type/' + itemId).update({
                    'updatedDate': '$now'
                });

                // Uodate the comment count.
                root.child('/items_by_community/' + community + '/' + itemId + '/comment_count').transaction((currentCount) {
                  if (currentCount == null || currentCount == 0) {
                    return 0;
                  } else {
                    return currentCount + 1;
                  }
                });
                root.child('/items_by_community_by_type/' + community + '/$type/' + itemId + '/comment_count').transaction((currentCount) {
                  if (currentCount == null || currentCount == 0) {
                    return 0;
                  } else {
                    return currentCount + 1;
                  }
                });

                // Update the priority sorting of the item to reflect updated date.
                DateTime time = DateTime.parse("$now");
                var epochTime = time.millisecondsSinceEpoch;
                root.child('/items_by_community/' + community + '/' + itemId).setPriority(-epochTime);
                root.child('/items_by_community_by_type/' + community + '/$type/' + itemId).setPriority(-epochTime);
                root.child('/items/' + itemId).setPriority(-epochTime);

                // Update the community itself.
                root.child('/communities/' + community).update({
                    'updatedDate': '$now'
                });
              });
            }
          });
        });
      });
    }

    updateParentItem(parent);

    var commentId = id.name;
    // Send a notification email to the item's author.
    HttpRequest.request(Routes.sendNotifications.toString() + "?itemid=$itemId&commentid=$commentId");

    // Reset the fields.
    theData['comment'] = "";

    // TODO: Focus the field: http://goo.gl/wDYQOx
//    var inp = querySelector('#comment') as CoreInput;
//    print(querySelector('#comment'));
//    inp.inputValue = '';
//    inp.querySelector('* /deep/ #input') // not yet supported with polyfills
//      ..focus();
  }

  signInWithFacebook() {
    app.signInWithFacebook();
  }

  fixItemCommunities() {
    var root = new db.Firebase(config['datastore']['firebaseLocation']);
      if (app.community != null) {
          // Update the community's copy of the item.
        root.child('/items/' + app.selectedItem['id'] + '/communities/' + app.community.alias)
          ..set(true);
      }
  }

  attached() {
    print("+ItemActivities");
    getActivities();
    fixItemCommunities();
  }

  detached() {
    print("-ItemActivities");
  }

  ItemActivities.created() : super.created();
}
