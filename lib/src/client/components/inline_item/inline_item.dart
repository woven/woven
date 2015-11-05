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
  @observable bool hasTriedLoadingItem;

  db.Firebase get f => app.f;

  get itemRef => f.child('/items/' + itemId);

  List<StreamSubscription> subscriptions = [];
  List<StreamSubscription> userSubscriptions = [];

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
    StreamSubscription onValue = itemRef.onValue.listen((e) {
      var queuedItem = toObservable(e.snapshot.val());

      if (queuedItem == null) {
        hasTriedLoadingItem = true;
        return;
      }

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
          queuedItem['defaultImage'] = 'custom-icons-fix:news';
          break;
        case 'message':
          queuedItem['defaultImage'] = 'communication:message';
          if (queuedItem['subject'] == null) queuedItem['subject'] = InputFormatter.createTeaser(queuedItem['message'], 75);
          if (queuedItem['body'] == null) queuedItem['body'] = queuedItem['message'];
//          queuedItem['subject'] ??= queuedItem['message']; // TODO Why don't null-aware operators work?
          break;
        case 'other':
          break;
        default:
          queuedItem['defaultImage'] = '';
      }

      // Handle any URI previews the item may have.
      if (queuedItem['uriPreviewId'] != null) {
        var onValue = f.child('/uri_previews/${queuedItem['uriPreviewId']}').onValue.listen((e) {
          var previewData = e.snapshot.val();
          UriPreview preview = UriPreview.fromJson(previewData);
          queuedItem['uriPreview'] = preview.toJson();
          queuedItem['uriPreview']['imageSmallLocation'] = (queuedItem['uriPreview']['imageSmallLocation'] != null) ? '${app.cloudStoragePath}/${queuedItem['uriPreview']['imageSmallLocation']}' : null;
          queuedItem['uriPreviewTried'] = true;

          // If subject and body are empty, use title and teaser from URI preview instead.
          if (queuedItem['subject'] == null) queuedItem['subject'] = toObservable(preview.title);
          if (queuedItem['body'] == null) queuedItem['body'] = toObservable(preview.teaser);;
        });
        subscriptions.add(onValue);
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

      var createdDate = queuedItem['createdDate'];
      queuedItem['formattedCreatedDate'] = InputFormatter.formatDate(createdDate.toLocal(), direction: 'past');

      queuedItem['comment_count'] = (queuedItem['comment_count'] != null) ? queuedItem['comment_count'] : 0;

      queuedItem['like_count'] = (queuedItem['like_count'] != null) ? queuedItem['like_count'] : 0;

      queuedItem['liked'] = false;


      listenForLikedState() {
        var likedItemsRef = f.child('/liked_by_user/' +
        app.user.username.toLowerCase() +
        '/items/' +
        queuedItem['id']);

        var likeStream = likedItemsRef.onValue.listen((e) {
          queuedItem['liked'] = e.snapshot.val() != null;
        });
        userSubscriptions.add(likeStream);
      }

      if (app.user != null) {
        listenForLikedState();
      }

      hasTriedLoadingItem = true;
      item = queuedItem;

      // If and when we have a user, see if they liked the item.
      var onUserChanged = app.onUserChanged.listen((UserModel user) {
        userSubscriptions.forEach((s) => s.cancel());
        userSubscriptions.clear();

        if (user == null) {
          item['liked'] = false;
        } else {
          var likedItemsRef = f.child('/liked_by_user/' +
          app.user.username.toLowerCase() +
          '/items/' +
          item['id']);

          userSubscriptions.add(likedItemsRef.onValue.listen((e) {
            item['liked'] = e.snapshot.val() != null;
          }));
        }
      });
      subscriptions.add(onUserChanged);
    });
    subscriptions.add(onValue);
  }

  // Unused. No stars at the moment.
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

    var likedItemRef = f.child('/liked_by_user/' + app.user.username.toLowerCase() + '/items/' + item['id']);
    var itemRef = f.child('/items/' + item['id']);

    if (item['liked']) {
      // If it's liked, time to unlike it.
      item['liked'] = false;
      likedItemRef.remove();

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
      // If it's not liked, time to like it.
      item['liked'] = true;

      likedItemRef.set(true);

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

  detached() {
    subscriptions.forEach((subscription) => subscription.cancel());
    userSubscriptions.forEach((subscription) => subscription.cancel());
  }
}
