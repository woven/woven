import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'dart:html';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:core_elements/core_pages.dart';
import 'package:woven/config/config.dart';

import 'dart:convert';
import 'package:crypto/crypto.dart';

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
    var f = new db.Firebase(firebaseLocation + '/items/' + app.community.alias);

    // TODO: Undo the limit of 20; https://github.com/firebase/firebase-dart/issues/8
    var lastItemsQuery = f.limit(20);
    lastItemsQuery.onChildAdded.listen((e) {
      var item = e.snapshot.val();

      // If no updated date, use the created date.
      if (item['updatedDate'] == null) {
        item['updatedDate'] = item['createdDate'];
      }

      // The live-date-time element needs parsed dates.
      item['updatedDate'] = DateTime.parse(item['updatedDate']);
      item['createdDate'] = DateTime.parse(item['createdDate']);

      // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location"
      // So we'll add that to our local item list.
      item['id'] = e.snapshot.name();

      // Insert each new item into the list.
      items.add(item);

      // Sort the list by the item's updatedDate, then reverse it.
      items.sort((m1, m2) => m1["updatedDate"].compareTo(m2["updatedDate"]));
      items = items.reversed.toList();

//      items.forEach((n) => print(n));
    });

    lastItemsQuery.onChildChanged.listen((e) {
      var item = e.snapshot.val();

      // If no updated date, use the created date.
      if (item['updatedDate'] == null) {
        item['updatedDate'] = item['createdDate'];
      }

      item['updatedDate'] = DateTime.parse(item['updatedDate']);

      // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location"
      // So we'll add that to our local item list.
      item['id'] = e.snapshot.name();

      // Insert each new item into the list.
      items.removeWhere((oldItem) => oldItem['id'] == e.snapshot.name());
      items.add(item);

      // Sort the list by the item's updatedDate, then reverse it.
      items.sort((m1, m2) => m1["updatedDate"].compareTo(m2["updatedDate"]));
      items = items.reversed.toList();
    });

  }

  void selectItem(Event e, var detail, Element target) {
    // Look in the items list for the item that matches the
    // id passed in the data-id attribute on the element.
    var item = items.firstWhere((i) => i['id'] == target.dataset['id']);

    app.selectedItem = item;
    app.selectedPage = 1;

    var str = target.dataset['id'];
    var bytes = UTF8.encode(str);
    var base64 = CryptoUtils.bytesToBase64(bytes);

    app.router.dispatch(url: "/item/$base64");
  }

  toggleLike(Event e, var detail, Element target) {
    // Don't fire the core-item's on-click, just the icon's.
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
    // Don't fire the core-item's on-click, just the icon's.
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

  InboxList.created() : super.created();

  //Temporary script, about as good a place as any to put it.

  CreateCommunityItemsScript() {
    var f = new db.Firebase(firebaseLocation + '/items');
    f.onChildAdded.listen((e) {
      var item = e.snapshot.val();
      // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location"
      // So we'll add that to our local item list.
      item['id'] = e.snapshot.name();

      final dbRef = new db.Firebase("$firebaseLocation/communities/thelab/item_index/${item['id']}");
      set(db.Firebase dbRef) {
        dbRef.set({
            'itemid': item['id']
        }).then((e){
          print("Updated ${item['subject']}");
        });
      }

      set(dbRef);

    });

  }

  attached() {
    print("+InboxList");
    app.pageTitle = "Everything";
    getItems();
    //CreateCommunityItemsScript();
  }

  detached() {
    print("-InboxList");
  }
}
