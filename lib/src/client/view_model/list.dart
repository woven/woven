library starred_view_model;

import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';

class StarredViewModel extends Observable {
  final App app;
  final List items = toObservable([]);
  final String firebaseLocation = config['datastore']['firebaseLocation'];

  StarredViewModel(this.app) {
    // TODO: Add more cases for various list types here later.
    loadStarredItemsForUser();
  }

  /**
   * Loads the user's starred items.
   */
  void loadStarredItemsForUser() {
    var f = new db.Firebase(firebaseLocation);
    var starredItemsByUserRef = f.child('/starred_by_user/' + app.user.username + '/items');

    // TODO: Undo the limit of 20; https://github.com/firebase/firebase-dart/issues/8
    starredItemsByUserRef.limit(20).onChildAdded.listen((e) {

      bool itemExists = false;
      if (items.isEmpty || items == null) {
        itemExists = false;
      } else {
        itemExists = (items.any((i) => i['id'] == e.snapshot.name())) ? true : false;
      }

      if (itemExists) {
        return;
      }

      f.child('/items/' + e.snapshot.name()).onValue.first.then((e) {
        bool itemExists = false;
        if (items.isEmpty || items == null) {
          itemExists = false;
        } else {
          itemExists = (items.any((i) => i['id'] == e.snapshot.name())) ? true : false;
        }

        if (itemExists) return;

        var item = toObservable(e.snapshot.val());

        // If no updated date, use the created date.
        if (item['updatedDate'] == null) {
          item['updatedDate'] = item['createdDate'];
        }

        // The live-date-time element needs parsed dates.
        item['updatedDate'] = DateTime.parse(item['updatedDate']);
        item['createdDate'] = DateTime.parse(item['createdDate']);

        item['id'] = e.snapshot.name();

        // Insert each new item into the list.
        items.add(toObservable(item));

        // Sort the list by the item's updatedDate.
        items.sort((m1, m2) => m2["updatedDate"].compareTo(m1["updatedDate"]));

        // Listen for realtime changes to the star count.
        f.child('/items/' + item['id'] + '/star_count').onValue.listen((e) {
          item['star_count'] = (e.snapshot.val() != null) ? e.snapshot.val() : 0;
        });

        // Listen for realtime changes to the like count.
        f.child('/items/' + item['id'] + '/like_count').onValue.listen((e) {
          item['like_count'] = (e.snapshot.val() != null) ? e.snapshot.val() : 0;
        });

        if (app.user != null) {
          var starredItemsRef = new db.Firebase(firebaseLocation + '/starred_by_user/' + app.user.username + '/items/' + item['id']);
          var likedItemsRef = new db.Firebase(firebaseLocation + '/liked_by_user/' + app.user.username + '/items/' + item['id']);
          starredItemsRef.onValue.listen((e) {
            item['starred'] = e.snapshot.val() != null;
          });
          likedItemsRef.onValue.listen((e) {
            item['liked'] = e.snapshot.val() != null;
          });
        } else {
          item['starred'] = false;
          item['liked'] = false;
        }
      });
    });

    starredItemsByUserRef.onChildRemoved.listen((e) {
      items.removeWhere((i) => i['id'] == e.snapshot.name());
    });

  }

  void toggleItemStar(id) {
    if (app.user == null) return app.showMessage("Kindly sign in first.", "important");

    var item = items.firstWhere((i) => i['id'] == id);

    var firebaseRoot = new db.Firebase(firebaseLocation);
    var starredItemRef = firebaseRoot.child('/starred_by_user/' + app.user.username + '/items/' + item['id']);
    var itemRef = firebaseRoot.child('/items/' + item['id']);

    if (item['starred']) {
      // If it's starred, time to unstar it.
      item['starred'] = false;
      starredItemRef.remove();

      // Update the star count.
      itemRef.child('/star_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          item['star_count'] = 0;
          return 0;
        } else {
          item['star_count'] = currentCount - 1;
          return item['star_count'];
        }
      });

      // Update the list of users who starred.
      firebaseRoot.child('/users_who_starred/item/' + item['id'] + '/' + app.user.username).remove();
    } else {
      // If it's not starred, time to star it.
      item['starred'] = true;
      starredItemRef.set(true);

      // Update the star count.
      itemRef.child('/star_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          item['star_count'] = 1;
          return 1;
        } else {
          item['star_count'] = currentCount + 1;
          return item['star_count'];
        }
      });

      // Update the list of users who starred.
      firebaseRoot.child('/users_who_starred/item/' + item['id'] + '/' + app.user.username).set(true);
    }
  }

  void toggleItemLike(id) {
    if (app.user == null) return app.showMessage("Kindly sign in first.", "important");

    var item = items.firstWhere((i) => i['id'] == id);

    var firebaseRoot = new db.Firebase(firebaseLocation);
    var starredItemRef = firebaseRoot.child('/liked_by_user/' + app.user.username + '/items/' + item['id']);
    var itemRef = firebaseRoot.child('/items/' + item['id']);

    if (item['liked']) {
      // If it's starred, time to unstar it.
      item['liked'] = false;
      starredItemRef.remove();

      // Update the star count.
      itemRef.child('/like_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          item['like_count'] = 0;
          return 0;
        } else {
          item['like_count'] = currentCount - 1;
          return item['like_count'];
        }
      });

      // Update the list of users who liked.
      firebaseRoot.child('/users_who_liked/item/' + item['id'] + '/' + app.user.username).remove();
    } else {
      // If it's not starred, time to star it.
      item['liked'] = true;
      starredItemRef.set(true);

      // Update the star count.
      itemRef.child('/like_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          item['like_count'] = 1;
          return 1;
        } else {
          item['like_count'] = currentCount + 1;
          return item['like_count'];
        }
      });

      // Update the list of users who liked.
      firebaseRoot.child('/users_who_liked/item/' + item['id'] + '/' + app.user.username).set(true);
    }
  }
}
