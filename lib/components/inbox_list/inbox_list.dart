import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
export 'package:polymer/init.dart';

@CustomTag('inbox-list')
class InboxList extends PolymerElement with Observable {
  @observable List items = toObservable([]);
  @observable List reverse;

  var f = new db.Firebase('https://luminous-fire-4671.firebaseio.com');

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

