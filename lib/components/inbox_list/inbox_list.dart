import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'dart:html';
export 'package:polymer/init.dart';

// *
// The InboxList class is for the list of inbox items, which is pulled from Firebase.
// *

@CustomTag('inbox-list')
class InboxList extends PolymerElement with Observable {
  @observable List items = toObservable([]);
  @observable List reverse;

  var f = new db.Firebase('https://luminous-fire-4671.firebaseio.com');

  //TODO: Move this out and pass in a List with a Polymer attribute?
  getItems() {
    f.onChildAdded.forEach((e) {
      // Insert each new item at top of list so the list is ascending
      items.insert(0, e.snapshot.val());
      //reverse = toObservable(items.reversed);
    });
  }

  void selectItem(Event e, var detail, Node target) {
    // TODO: Is there a better way to find the .item-text in the core-item?
    var message = target.childNodes[1].text;
    print("Item clicked! $message");
    window.alert("You selected: $message");
  }

  InboxList.created() : super.created() {
    getItems();
  }

  attached() => print("+InboxList");
  detached() => print("-InboxList");

}

