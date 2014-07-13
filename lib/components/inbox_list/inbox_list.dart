import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'dart:html';
import '../../src/input_formatter.dart';
//export 'package:polymer/init.dart';


// *
// The InboxList class is for the list of inbox items, which is pulled from Firebase.
// *

@CustomTag('inbox-list')
class InboxList extends PolymerElement with Observable {
  @observable List items = toObservable([]);

  var f = new db.Firebase('https://luminous-fire-4671.firebaseio.com/nodes');

  //TODO: Move this out and pass in a List with a Polymer attribute?
  getItems() {
    f.onChildAdded.listen((e) {
      var node = e.snapshot.val();
      var createdAgo =  InputFormatter.formatMomentDate(DateTime.parse(node['createdDate']));
      node['createdDate'] = createdAgo;

      // Insert each new item at top of list so the list is ascending
      items.insert(0, node);
    });
  }

  void selectItem(Event e, var detail, Element target) {
    var message = target.dataset['msg'];
    //var message = target.childNodes[1].text;
    print("Item clicked: $message");
    window.alert("You selected: $message");
  }

  InboxList.created() : super.created() {
    getItems();
  }

  attached() => print("+InboxList");
  detached() => print("-InboxList");

}

