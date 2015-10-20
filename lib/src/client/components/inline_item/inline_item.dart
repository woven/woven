import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/src/client/view_model/base.dart';
import 'package:woven/src/client/model/user.dart';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/**
 * A list of items.
 */
@CustomTag('inline-item')
class InlineItem extends PolymerElement with Observable {
  @published String itemId;
  @published App app;
//  @published FeedViewModel viewModel;
  @observable Map item;

  db.Firebase get f => app.f;

  get itemRef => f.child('/items/' + itemId);

  List<StreamSubscription> subscriptions = [];

  InlineItem.created() : super.created();

//  InputElement get subject => $['subject'];

//  @ComputedProperty("item['body']")
//  String get formattedBody => InputFormatter.createTeaser(item['body'], 75);
//
//  @ComputedProperty("item['subject']")
//  String get formattedSubject => InputFormatter.createTeaser(item['subject'], 75);

  void selectItem(Event e, var detail, Element target) {
    // Look in the items list for the item that matches the
    // id passed in the data-id attribute on the element.
    var item = viewModel.items.firstWhere((i) => i['id'] == target.dataset['id']);

    app.router.previousPage = app.router.selectedPage;
    app.router.selectedItem = item;
    app.router.selectedPage = 'item';

    var str = target.dataset['id'];
    var bytes = UTF8.encode(str);
    var base64 = CryptoUtils.bytesToBase64(bytes);

    app.router.dispatch(url: "/item/$base64");
  }

  /**
   * Get the item.
   */
  getItem() {
    StreamSubscription subscription = itemRef.onValue.listen((e) {
      var queuedItem = toObservable(e.snapshot.val());

      // Make sure we're using the collapsed username.
      queuedItem['user'] = (queuedItem['user'] as String).toLowerCase();

//      String usernameForDisplay = await UserModel.usernameForDisplay(queuedItem['user'], f, app.cache);
//      queuedItem['usernameForDisplay'] = usernameForDisplay;

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
          if (queuedItem['subject'] == null) queuedItem['subject'] = InputFormatter.createTeaser(queuedItem['message'], 75);
          if (queuedItem['body'] == null) queuedItem['body'] = queuedItem['message'];
//          queuedItem['subject'] ??= queuedItem['message']; // TODO Why don't null-aware operators work?
          break;
        case 'other':
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
          if (queuedItem['body'] == null) queuedItem['body'] = toObservable(preview.teaser);;
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
      // So we'll add that to our local item.
      queuedItem['id'] = e.snapshot.key;

      queuedItem['formattedBody'] = InputFormatter.createTeaser(queuedItem['body'], 75);

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

      loadItemUserStarredLikedInformation();
    });

    subscriptions.add(subscription);

//    listenForChanges();
  }

  /* Deprecated at the moment. */
  listenForChanges()  {
    // Listen for changed items.

    var onChildChanged = itemRef.onChildChanged.listen((e) {
      Map currentData = item;
      Map newData = e.snapshot.val();

      // Make sure we're using the collapsed username.
      newData['user'] = (newData['user'] as String).toLowerCase();

      Future processData = new Future.sync(() {
        // First pre-process some things.
        if (newData['createdDate'] != null) newData['createdDate'] = DateTime.parse(newData['createdDate']);
        if (newData['updatedDate'] != null) newData['updatedDate'] = DateTime.parse(newData['updatedDate']);
        if (newData['startDateTime'] != null) newData['startDateTime'] = DateTime.parse(newData['startDateTime']);
        if (newData['star_count'] == null) newData['star_count'] = 0;
        if (newData['like_count'] == null) newData['like_count'] = 0;

        if (newData['uriPreviewId'] != null) {
          // Get the associated URI preview.
          return f.child('/uri_previews/${newData['uriPreviewId']}').once('value').then((e) {
            var previewData = e.val();
            UriPreview preview = UriPreview.fromJson(previewData);
            newData['uriPreview'] = preview.toJson();
            newData['uriPreview']['imageSmallLocation'] = (newData['uriPreview']['imageSmallLocation'] != null) ? '${app.cloudStoragePath}/${newData['uriPreview']['imageSmallLocation']}' : null;
            newData['uriPreviewTried'] = true;

            // If item's subject/body are empty, use any title/teaser from URI preview instead.
            if (newData['subject'] == null) newData['subject'] = preview.title;
            if (newData['body'] == null) newData['body'] = preview.teaser;
          });
        }
      }).then((_) {
        // Now that new data is pre-processed, update current data.
        newData.forEach((k, v) => currentData[k] = v);
        item = currentData;
      });
    });
    subscriptions.add(onChildChanged);
  }

  void loadItemUserStarredLikedInformation() {
    if (itemId == null) return;

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

  /**
   * Format the given string with "a" or "an" or none.
   */
  formatWordArticle(String content) => InputFormatter.formatWordArticle(content);

  formatItemDate(DateTime value) => InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);

  // TODO: Bring back endDate, currently null.
  formatEventDate(DateTime startDate) => InputFormatter.formatDate(startDate.toLocal(), showHappenedPrefix: true, trimPast: true);

  stopProp(Event e) => e.stopPropagation();

  attached() => getItem();

  detached() => subscriptions.forEach((subscription) => subscription.cancel());
}
