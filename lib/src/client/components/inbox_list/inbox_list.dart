import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'dart:html';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:core_elements/core_pages.dart';
import 'package:woven/config/config.dart';

// *
// The InboxList class is for the list of inbox items, which is pulled from Firebase.
// *
@CustomTag('inbox-list')
class InboxList extends PolymerElement with Observable {
  @published App app;
  @observable List items = toObservable([]);

  InputElement get subject => $['subject'];
  var firebaseLocation = config['datastore']['firebaseLocation'];

  //TODO: Move this out and pass in a List with a Polymer attribute?

  getItems() {
    var f = new db.Firebase(firebaseLocation + '/items');

    // TODO: Undo the limit of 20; https://github.com/firebase/firebase-dart/issues/8
    var lastItemsQuery = f.limit(20);
    lastItemsQuery.onChildAdded.listen((e) {
      var item = e.snapshot.val();
      item['createdDate'] = DateTime.parse(item['createdDate']);

      // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location"
      // So we'll add that to our local item list
      item['id'] = e.snapshot.name();

      // Insert each new item at top of list so the list is ascending
      items.insert(0, item);
    });
  }

  void selectItem(Event e, var detail, Element target) {
    // Look in the items list for the item that matches the
    // id passed in the data-id attribute on the element
    var item = items.firstWhere((i) => i['id'] == target.dataset['id']);

    app.selectedItem = item;
    app.selectedPage = 1;
  }

  toggleLike(Event e, var detail, Element target) {
    // Don't fire the core-item's on-click, just the icon's
    e.stopPropagation();

    if (target.attributes["icon"] == "favorite") {
      target.attributes["icon"] = "favorite-outline";
    } else {
      target.attributes["icon"] = "favorite";
    }

    target
      ..classes.toggle("selected");
  }

  toggleStar(Event e, var detail, Element target) {
    // Don't fire the core-item's on-click, just the icon's
    e.stopPropagation();
    target
      ..classes.toggle("selected");

    if (target.attributes["icon"] == "star") {
      target.attributes["icon"] = "star-outline";
    } else {
      target.attributes["icon"] = "star";
    }
  }

  formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  InboxList.created() : super.created() {

  }

  attached() {
    getItems();
    print("+InboxList");
//    app.changeTitle("Everything");
  }

  detached() {
    app.changeTitle("");
    print("-InboxList");
  }
}
