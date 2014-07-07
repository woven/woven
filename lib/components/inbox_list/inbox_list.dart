import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
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
      items.insert(0, e.snapshot.val());
      //reverse = toObservable(items.reversed);
    });
  }

  InboxList.created() : super.created() {
    getItems();
  }

  attached() => print("+InboxList");
  detached() => print("-InboxList");

}

