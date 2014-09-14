library item_view_model;

import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ItemViewModel extends Observable {
  final App app;
  @observable Map item = toObservable({});
  final String firebaseLocation = config['datastore']['firebaseLocation'];

  ItemViewModel(this.app) {
    getItem();
  }

  /**
   * Format the body for line breaks.
   */
//  get formattedBody {
//    if (app.selectedItem == null) return '';
//    return "${InputFormatter.nl2br(app.selectedItem['body'])}";
//  }

  /**
   * Get the item.
   */
  void getItem() {
    if (app.selectedItem != null) {
      item = app.selectedItem;

    } else {
      // If there's no app.selectedItem, we probably
      // came here directly, so let's get it.
      // Decode the base64 URL and determine the item.
      var base64 = Uri.parse(window.location.toString()).pathSegments[1];
      var bytes = CryptoUtils.base64StringToBytes(base64);
      var decodedItem = UTF8.decode(bytes);

      var f = new db.Firebase(firebaseLocation);

      f.child('/items/' + decodedItem).onValue.first.then((e) {
        item = toObservable(e.snapshot.val());

        // The live-date-time element needs parsed dates.
        item['createdDate'] = DateTime.parse(item['createdDate']);

        // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location"
        // So we'll add that to our local item list.
        item['id'] = e.snapshot.name();

        // Listen for realtime changes to the star count.
        f.child('/items/' + item['id'] + '/star_count').onValue.listen((e) {
          item['star_count'] = (e.snapshot.val() != null) ? e.snapshot.val() : 0;
        });

        // Listen for realtime changes to the like count.
        f.child('/items/' + item['id'] + '/like_count').onValue.listen((e) {
          item['like_count'] = (e.snapshot.val() != null) ? e.snapshot.val() : 0;
        });

        app.selectedItem = item;

      }).then((e) {
        loadItemUserStarredLikedInformation();
      });
    }
  }

  void loadItemUserStarredLikedInformation() {
    var f = new db.Firebase(config['datastore']['firebaseLocation']);
    if (app.user != null && !item.isEmpty) {
      var starredItemsRef = f.child('/starred_by_user/' + app.user.username + '/items/' + item['id']);
      var likedItemsRef = f.child('/liked_by_user/' + app.user.username + '/items/' + item['id']);
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
  }


  void toggleStar() {
    if (app.user == null) return app.showMessage("Kindly sign in first.", "important");

    var f = new db.Firebase(config['datastore']['firebaseLocation']);
    var starredItemRef = f.child('/starred_by_user/' + app.user.username + '/items/' + item['id']);
    var itemRef = f.child('/items/' + item['id']);

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
      f.child('/users_who_starred/item/' + item['id'] + '/' + app.user.username).remove();
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
      f.child('/users_who_starred/item/' + item['id'] + '/' + app.user.username).set(true);
    }
  }

  void toggleLike() {
    if (app.user == null) return app.showMessage("Kindly sign in first.", "important");

    var f = new db.Firebase(config['datastore']['firebaseLocation']);
    var starredItemRef = f.child('/liked_by_user/' + app.user.username + '/items/' + item['id']);
    var itemRef = f.child('/items/' + item['id']);

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
      f.child('/users_who_liked/item/' + item['id'] + '/' + app.user.username).remove();
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
      f.child('/users_who_liked/item/' + item['id'] + '/' + app.user.username).set(true);
    }
  }


}
