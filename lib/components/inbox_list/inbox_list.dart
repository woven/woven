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

  CorePages get pages =>  $['pages'];
  InputElement get subject => $['subject'];

  //TODO: Move this out and pass in a List with a Polymer attribute?
  getItems() {
    f.onChildAdded.listen((e) {
      var item = e.snapshot.val();
      item['createdDate'] = DateTime.parse(item['createdDate']);

      // Insert each new item at top of list so the list is ascending
      items.insert(0, item);
    });
  }

  void selectItem(Event e, var detail, Element target) {
    var message = target.dataset['msg'];
    print(app);
    //app.selectedItem = message;

    pages.selected = 1;
    print(pages);
    print(pages.runtimeType.toString());

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
