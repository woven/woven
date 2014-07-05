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
      items.add(e.snapshot.val());
      reverse = toObservable(items.reversed);
      print(e.snapshot.val());
    });
  }

  InboxList.created() : super.created() {
    getItems();
    //items = items.reversed.toList();
  }

  attached() => print("+b");
  detached() => print("-b");

}

