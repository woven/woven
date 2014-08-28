import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:core_elements/core_input.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

@CustomTag('item-activities')
class ItemActivities extends PolymerElement {
  @published App app;
  @observable List comments = toObservable([]);

  CoreInput get name => $['name'];
  CoreInput get comment => $['comment'];
  var firebaseLocation = config['datastore']['firebaseLocation'];

  String formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

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
      comment['id'] = e.snapshot.name();

      // Insert each new item at top of list so the list is ascending.
      comments.insert(0, comment);
    });
  }

  //
  // Add a comment to /activities/comments for this item.
  //
  addComment(Event e, var detail, Element target) {
    e.preventDefault();

    if (name.inputValue.trim().isEmpty) { window.alert("Your name is empty."); return false; }
    if (comment.inputValue.trim().isEmpty) { window.alert("Your comment is empty."); return false; }

    var itemId = app.selectedItem['id'];

    DateTime now = new DateTime.now().toUtc();

    // Add the comment.
    final comments = new db.Firebase(firebaseLocation + '/items/' + itemId + '/activities/comments');

    Future set(db.Firebase comments) {
      comments.push().set({
          'user': name.inputValue,
          'comment': comment.inputValue,
          'createdDate': '$now'
      }).then((e){});
    }

    set(comments);

    // Update some details on the parent item.
    final item = new db.Firebase(firebaseLocation + '/items/' + itemId);

    // TODO: About time to create a item model?
    Future update(db.Firebase item) {
      item.update({
        'updatedDate': '$now'
      }).then((e){});
    }

    update(item);

    // Reset the fields.
    comment.inputValue = "";
    // TODO: Focus the field: http://goo.gl/wDYQOx
  }

  signInWithFacebook() {
    app.signInWithFacebook();
  }

  attached() {
    print("+ItemActivities");
    getActivities();
  }

  detached() {
    print("-ItemActivities");
  }

  ItemActivities.created() : super.created();
}
