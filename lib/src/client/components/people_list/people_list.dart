import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'dart:html';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:core_elements/core_pages.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/components/page/woven_app/woven_app.dart' show showToastMessage;

import 'dart:convert';
import 'package:crypto/crypto.dart';

// *
// The InboxList class is for the list of inbox items, which is pulled from Firebase.
// *
@CustomTag('people-list')
class PeopleList extends PolymerElement with Observable {
  @published App app;
  @observable List users = toObservable([]);

  PeopleList.created() : super.created();

  InputElement get subject => $['subject'];
  var firebaseLocation = config['datastore']['firebaseLocation'];

  //TODO: Move this out and pass in a List with a Polymer attribute?

  getUsers() {
    var f = new db.Firebase(firebaseLocation + '/users');

    // TODO: Undo the limit of 20; https://github.com/firebase/firebase-dart/issues/8
    var lastUsersQuery = f.limit(20);
    lastUsersQuery.onChildAdded.listen((e) {
      var user = e.snapshot.val();

      if (user['createdDate'] == null) {
        // Some temporary code that stored a createdDate where this was none.
        // It's safe to leave active as it only affects an empty createdDate.
        DateTime newDate = new DateTime.utc(2014, DateTime.AUGUST, 21, 12);
        var temp = new db.Firebase(firebaseLocation + "/users/${user['username']}");
        temp.update({'createdDate': newDate});
        user['createdDate'] = newDate;
      }

      // The live-date-time element needs parsed dates.
      user['createdDate'] = DateTime.parse(user['createdDate']);

      // Insert each new item into the list.
      users.add(user);

      // Sort the list by the item's updatedDate, then reverse it.
      users.sort((m1, m2) => m1["createdDate"].compareTo(m2["createdDate"]));
      users = users.reversed.toList();
    });

//    lastPeopleQuery.onChildChanged.listen((e) {
//      var item = e.snapshot.val();
//
//      // If no updated date, use the created date.
//      if (person['updatedDate'] == null) {
//        item['updatedDate'] = item['createdDate'];
//      }
//
//      item['updatedDate'] = DateTime.parse(item['updatedDate']);
//
//      // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location"
//      // So we'll add that to our local item list.
//      item['id'] = e.snapshot.name();
//
//      // Insert each new item into the list.
//      items.removeWhere((oldItem) => oldItem['id'] == e.snapshot.name());
//      items.add(item);
//
//      // Sort the list by the item's updatedDate, then reverse it.
//      items.sort((m1, m2) => m1["updatedDate"].compareTo(m2["updatedDate"]));
//      items = items.reversed.toList();
//    });

  }

  void selectUser(Event e, var detail, Element target) {
    var selectedUser = target.dataset['user'];
    // TODO: Revisit this? Odd way of doing this, see: http://goo.gl/LJcuzR
    document.querySelector("woven-app").showToastMessage("More about $selectedUser coming soon!", "important");

    // TODO: User pages, routes, etc.
  }

  formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  attached() {
    getUsers();
    app.pageTitle = "People";
  }

  detached() {
  }
}
