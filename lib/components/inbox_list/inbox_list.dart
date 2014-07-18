import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'dart:html';
import '../../src/input_formatter.dart';
import '../../src/app.dart';
import 'package:core_elements/core_pages.dart';

// *
// The InboxList class is for the list of inbox items, which is pulled from Firebase.
// *

@CustomTag('inbox-list')
class InboxList extends PolymerElement with Observable {
  @published App app;
  @observable List items = toObservable([]);

  var f = new db.Firebase('https://luminous-fire-4671.firebaseio.com/nodes');

  InputElement get subject => $['subject'];

  //TODO: Move this out and pass in a List with a Polymer attribute?
  getItems() {
    f.onChildAdded.listen((e) {
      var item = e.snapshot.val();
      item['createdDate'] = DateTime.parse(item['createdDate']);

      // This is Firebase's ID, i.e. "the name of the Firebase location"
      print(e.snapshot.name());
      // So we'll add that to our local list
      item['id'] = e.snapshot.name();

      // Insert each new item at top of list so the list is ascending
      items.insert(0, item);
    });
  }

  void selectItem(Event e, var detail, Element target) {
    // If your items had an ID, you would find the actual item based on its ID.
    // I'm finding the item based on the body for now.
    var item = items.firstWhere((i) => i['body'] == target.dataset['body']);

    app.selectedItem = item;
    app.selectedPage = 1;
  }

  toggleLike(Event e, var detail, Element target) {
    // Prevent the whole core-item's on-click event from firing
    e.stopPropagation();
    target..classes.toggle("selected");

    if (target.attributes["icon"] == "favorite") {
      target.attributes["icon"] = "favorite-outline";
    } else {
      target.attributes["icon"] = "favorite";
    }
  }

  toggleStar(Event e, var detail, Element target) {
    // Prevent the whole core-item's on-click event from firing
    e.stopPropagation();
    target..classes.toggle("selected");

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
    getItems();
  }

  attached() => print("+InboxList");
  detached() => print("-InboxList");
}
