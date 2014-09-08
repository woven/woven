library inbox_view_model;

import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';

class InboxViewModel extends Observable {
  final App app;
  final List items = toObservable([]);
  final String firebaseLocation = config['datastore']['firebaseLocation'];

  InboxViewModel(this.app) {
    loadItemsForCommunity();
  }

  /**
   * Loads the communities.
   */
  void loadItemsForCommunity() {
    var f = new db.Firebase(firebaseLocation);
    var itemsByCommunityRef = f.child('/items_by_community/' + app.community.alias);

    // TODO: Undo the limit of 20; https://github.com/firebase/firebase-dart/issues/8
    itemsByCommunityRef.limit(20).onChildAdded.listen((e) {
      var item = toObservable(e.snapshot.val());

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
      items.reversed.toList();

      // Listen for realtime changes to the star count.
      itemsByCommunityRef.child('/star_count').onValue.listen((e) {
        item['star_count'] = e.snapshot.val();
      });
    });
  }

  void toggleItemStar(id) {
    if (app.user == null) return app.showMessage("Kindly sign in first.", "important");

    var item = items.firstWhere((i) => i['id'] == id);

    print(item);

//    var f = new db.Firebase(firebaseLocation);
//    var starredItemsRef = f.child('/starred_by_user/' + app.user.username + '/items/' + item['id']);
//    var itemRef = f.child('/items/' + item['id']);
//    var itemRefByCommunity = f.child('/items_by_community/' + app.community.alias);
//
//    if (community['starred']) {
//      // If it's starred, time to unstar it.
//      community['starred'] = false;
//      starredCommunityRef.remove();
//
//      // Update the star count.
//      communityRef.child('/star_count').transaction((currentCount) {
//        if (currentCount == null || currentCount == 0) {
//          community['star_count'] = 0;
//          return 0;
//        } else {
//          community['star_count'] = currentCount - 1;
//          return community['star_count'];
//        }
//      });
//
//      // Update the list of users who starred.
//      firebaseRoot.child('/users_who_starred/community/' + app.community.alias + '/' + app.user.username).remove();
//    } else {
//      // If it's not starred, time to star it.
//      community['starred'] = true;
//      starredCommunityRef.set(true);
//
//      // Update the star count.
//      communityRef.child('/star_count').transaction((currentCount) {
//        if (currentCount == null || currentCount == 0) {
//          community['star_count'] = 1;
//          return 1;
//        } else {
//          community['star_count'] = currentCount + 1;
//          return community['star_count'];
//        }
//      });
//
//      // Update the list of users who starred.
//      firebaseRoot.child('/users_who_starred/community/' + app.community.alias + '/' + app.user.username).set(true);
//    }
  }


}
