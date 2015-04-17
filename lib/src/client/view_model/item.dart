library item_view_model;

import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'package:woven/src/client/view_model/base.dart';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/client/model/user.dart';

class ItemViewModel extends BaseViewModel with Observable {
  final App app;
  @observable Map item = toObservable({});

  db.Firebase get f => app.f;

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
    if (item.length == 0) onLoadCompleter.complete(true);

    if (app.router.selectedItem != null) {
      item = app.router.selectedItem;

    } else {
      // If there's no app.selectedItem, we probably
      // came here directly, so let's get it using the URL.
      var encodedItem = Uri.parse(window.location.toString()).pathSegments[1];
      var decodedItem = base64Decode(encodedItem);

      f.child('/items/' + decodedItem).onValue.first.then((e) {
        // We hold the item in a separate var while we pre-process it.
        var queuedItem = toObservable(e.snapshot.val());

        // Make sure we're using the collapsed username.
        queuedItem['user'] = (queuedItem['user'] as String).toLowerCase();

        return UserModel.usernameForDisplay(queuedItem['user'], f, app.cache).then((String usernameForDisplay) {
          queuedItem['usernameForDisplay'] = usernameForDisplay;

          // If no updated date, use the created date.
          // TODO: We assume createdDate is never null!
          if (queuedItem['updatedDate'] == null) {
            queuedItem['updatedDate'] = queuedItem['createdDate'];
          }

          // The live-date-time element needs parsed dates.
          queuedItem['createdDate'] = DateTime.parse(queuedItem['createdDate']);
          queuedItem['updatedDate'] = DateTime.parse(queuedItem['updatedDate']);

          switch (queuedItem['type']) {
            case 'event':
              if (queuedItem['startDateTime'] != null) queuedItem['startDateTime'] = DateTime.parse(queuedItem['startDateTime']);
              queuedItem['defaultImage'] = 'event';
              break;
            case 'announcement':
              queuedItem['defaultImage'] = 'announcement';
              break;
            case 'news':
              queuedItem['defaultImage'] = 'custom-icons:news';
              break;
            case 'message':
            case 'other':
              queuedItem['type'] = null;
              break;
            default:
          }

          // Handle any URI previews the item may have.
          if (queuedItem['uriPreviewId'] != null) {
            f.child('/uri_previews/${queuedItem['uriPreviewId']}').onValue.listen((e) {
              var previewData = e.snapshot.val();
              UriPreview preview = UriPreview.fromJson(previewData);
              queuedItem['uriPreview'] = preview.toJson();
              queuedItem['uriPreview']['imageSmallLocation'] = (queuedItem['uriPreview']['imageSmallLocation'] != null) ? '${app.cloudStoragePath}/${queuedItem['uriPreview']['imageSmallLocation']}' : null;
              queuedItem['uriPreviewTried'] = true;

              // If subject and body are empty, use title and teaser from URI preview instead.
              if (queuedItem['subject'] == null) queuedItem['subject'] = toObservable(preview.title);
              if (queuedItem['body'] == null) queuedItem['body'] =  toObservable(preview.teaser);;
            });
          } else {
            queuedItem['uriPreviewTried'] = true;
          }

          // Format the URL for display.
          if (queuedItem['url'] != null) {
            String uriHost = Uri.parse(queuedItem['url']).host;
            String uriHostShortened = uriHost.substring(uriHost.toString().lastIndexOf(".", uriHost.toString().lastIndexOf(".") - 1) + 1);
            queuedItem['uriHost'] = uriHostShortened;
          }

          // snapshot.key is Firebase's ID, i.e. "the name of the Firebase location"
          // So we'll add that to our local item list.
          queuedItem['id'] = e.snapshot.key;

          // Listen for realtime changes to the star count.
          f.child('/items/' + queuedItem['id'] + '/star_count').onValue.listen((e) {
            queuedItem['star_count'] = (e.snapshot.val() != null) ? e.snapshot.val() : 0;
          });

          // Listen for realtime changes to the like count.
          f.child('/items/' + queuedItem['id'] + '/like_count').onValue.listen((e) {
            queuedItem['like_count'] = (e.snapshot.val() != null) ? e.snapshot.val() : 0;
          });

          // Listen for realtime changes to the comment count.
          f.child('/items/' + queuedItem['id'] + '/comment_count').onValue.listen((e) {
            queuedItem['comment_count'] = (e.snapshot.val() != null) ? e.snapshot.val() : 0;
          });

          item = queuedItem;
          app.router.selectedItem = item;
        });
      }).then((e) {
        loadItemUserStarredLikedInformation();
      });
    }
  }

  void loadItemUserStarredLikedInformation() {
    if (item['id'] == null) return;

    if (app.user != null && !item.isEmpty) {
      var starredItemsRef = f.child('/starred_by_user/' + app.user.username.toLowerCase() + '/items/' + item['id']);
      var likedItemsRef = f.child('/liked_by_user/' + app.user.username.toLowerCase() + '/items/' + item['id']);
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

    var starredItemRef = f.child('/starred_by_user/' + app.user.username.toLowerCase() + '/items/' + item['id']);
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
      f.child('/users_who_starred/item/' + item['id'] + '/' + app.user.username.toLowerCase()).remove();
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
      f.child('/users_who_starred/item/' + item['id'] + '/' + app.user.username.toLowerCase()).set(true);
    }
  }

  void toggleLike() {
    if (app.user == null) return app.showMessage("Kindly sign in first.", "important");

    var starredItemRef = f.child('/liked_by_user/' + app.user.username.toLowerCase() + '/items/' + item['id']);
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
      f.child('/users_who_liked/item/' + item['id'] + '/' + app.user.username.toLowerCase()).remove();
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
      f.child('/users_who_liked/item/' + item['id'] + '/' + app.user.username.toLowerCase()).set(true);
    }
  }
}
