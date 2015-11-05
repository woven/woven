library feed_view_model;

import 'dart:async';
import 'dart:html';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as fb;

import 'base.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/date_group.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'package:woven/src/client/model/user.dart';

class FeedViewModel extends BaseViewModel with Observable {
  final App app;
  final List items = toObservable([]);
  final Map groupedItems = toObservable({});

  String dataLocation = '';
  @observable String typeFilter;

  int pageSize = 20;
  @observable bool reloadingContent = false;
  @observable bool reachedEnd = false;
  var lastPriority = null;
  var topPriority = null;
  var secondToLastPriority = null;

  fb.Firebase get f => app.f;

  StreamSubscription childAddedSubscriber,
      childChangedSubscriber,
      childMovedSubscriber,
      childRemovedSubscriber;

  List<StreamSubscription> userSubscriptions = [];

  FeedViewModel({this.app, this.typeFilter}) {
    if (typeFilter == 'event') {
      var now = new DateTime.now();
      DateTime startOfToday = new DateTime(now.year, now.month, now.day);
      topPriority =
          lastPriority = startOfToday.toUtc().millisecondsSinceEpoch.toString();
    } else {
      topPriority == null;
    }

    if (app.debugMode) print(
        'DEBUG: Called feedViewModel constructor // typeFilter: $typeFilter');

    loadItemsByPage();
  }

  /**
   * Load more items pageSize at a time.
   */
  loadItemsByPage() {
    reloadingContent = true;
    int count = 0;

    if (typeFilter != null) {
      dataLocation = '/items_by_community_by_type/' +
          app.community.alias +
          '/' +
          typeFilter;
    } else {
      dataLocation = '/items_by_community/' + app.community.alias;
    }

    fb.Query itemsRef;
    if (typeFilter == 'event') {
      itemsRef = f
          .child(dataLocation)
          .orderByChild('startDateTimePriority')
          .startAt(value: lastPriority)
          .limitToFirst(pageSize + 1);
    } else {
      itemsRef = f
          .child(dataLocation)
          .startAt(value: lastPriority)
          .limitToFirst(pageSize + 1);
    }

    if (items.length == 0) onLoadCompleter.complete(true);

    // Get the list of items, and listen for new ones.
    itemsRef.once('value').then((snapshot) {
      if (app.debugMode) print('DEBUG: itemRef.once called');
      snapshot.forEach((itemSnapshot) {
        count++;
        Map item = itemSnapshot.val();

        // Use the Firebase snapshot ID as our ID.
        item['id'] = itemSnapshot.key;

        // Track the snapshot's priority so we can paginate from the last one.
        if (typeFilter == 'event') {
          lastPriority = '${item['startDateTimePriority']}';
        } else {
          lastPriority = itemSnapshot.getPriority();
        }

        if (app.debugMode) print(
            'DEBUG: $count // key: ${itemSnapshot.key} // lastPriority: ${lastPriority}');

        // Don't process the extra item we tacked onto pageSize in the limit() above.
        if (count > pageSize) return;

        // Remember the priority of the last item, excluding the extra item which we ignore above.
        if (typeFilter == 'event') {
          secondToLastPriority = item['startDateTimePriority'];
        } else {
          secondToLastPriority = itemSnapshot.getPriority();
        }

        // TODO: This seems weird. I do it so I can separate out the method for adding to the list.
        items.add(toObservable(processItem(itemSnapshot)));
      });

      updateGroupedView();

      listenForNewItems(startAt: topPriority, endAt: secondToLastPriority);

      // If we received less than we tried to load, we've reached the end.
      if (count <= pageSize) reachedEnd = true;
      reloadingContent = false;
    });
  }

  /**
   * Listen for new stuff within the items we're currently showing.
   */
  listenForNewItems({startAt, endAt}) {
    if (app.debugMode) print(
        'DEBUG: listenForNewItems start: $startAt // end: $endAt');

    // Kill any old listeners, because we want a new one for the new range in its entirety.
    if (childAddedSubscriber != null) {
      childAddedSubscriber.cancel();
      childAddedSubscriber = null;
    }
    if (childChangedSubscriber != null) {
      childChangedSubscriber.cancel();
      childChangedSubscriber = null;
    }
    if (childMovedSubscriber != null) {
      childMovedSubscriber.cancel();
      childMovedSubscriber = null;
    }
    if (childRemovedSubscriber != null) {
      childRemovedSubscriber.cancel();
      childRemovedSubscriber = null;
    }

    if (typeFilter != null) {
      dataLocation = '/items_by_community_by_type/' +
          app.community.alias +
          '/' +
          typeFilter;
    } else {
      dataLocation = '/items_by_community/' + app.community.alias;
    }

    // Find the index of the item with the closest createdDate.
    indexOfClosestItemByDate(date) {
      for (var item in items) {
        if ((item['createdDate'] as DateTime).isAfter(date)) return items
            .indexOf(item);
      }
    }

    // For events, fFind the index of the item with the closest start date.
    indexOfClosestItemByStartDate(date) {
      for (var item in items) {
        if ((item['startDateTime'] as DateTime).isAfter(date)) return items
            .indexOf(item);
      }
    }

    // If this is the first item loaded, start listening for new items.
    fb.Firebase itemsRef;

    if (typeFilter == 'event') {
      itemsRef = f
          .child(dataLocation)
          .orderByChild('startDateTimePriority')
          .startAt(value: startAt)
          .endAt(value: endAt);
    } else {
      itemsRef = f
          .child(dataLocation)
          .orderByPriority()
          .startAt(value: startAt)
          .endAt(value: endAt);
    }

    // Listen for new items.
    childAddedSubscriber = itemsRef.onChildAdded.listen((fb.Event e) {
      Map newItem = e.snapshot.val();

      if (app.debugMode) print('DEBUG: Child added: ${e.snapshot.key}');

      // Make sure we're using the collapsed username.
      newItem['user'] = (newItem['user'] as String).toLowerCase();

      // Use the Firebase snapshot ID as our ID.
      newItem['id'] = e.snapshot.key;

      var existingItem = items.firstWhere((i) => i['id'] == e.snapshot.key,
          orElse: () => null);
      if (existingItem != null) return;

      var index;
      if (typeFilter == 'event') {
        index = indexOfClosestItemByStartDate(
            DateTime.parse(newItem['startDateTime']));
      } else {
        index =
            indexOfClosestItemByDate(DateTime.parse(newItem['updatedDate']));
      }

      items.insert(
          index == null ? 0 : index, toObservable(processItem(e.snapshot)));

      if (typeFilter == 'event' || typeFilter == 'news') {
        updateGroupedView();
      }
    });

    // Listen for changed items.
    childChangedSubscriber = itemsRef.onChildChanged.listen((e) {
      Map currentData = items.firstWhere((i) => i['id'] == e.snapshot.key);
      Map newData = e.snapshot.val();

      // Make sure we're using the collapsed username.
      newData['user'] = (newData['user'] as String).toLowerCase();

      new Future.sync(() {
        // First pre-process some things.
        if (newData['createdDate'] != null) newData['createdDate'] =
            DateTime.parse(newData['createdDate']);
        if (newData['updatedDate'] != null) newData['updatedDate'] =
            DateTime.parse(newData['updatedDate']);
        if (newData['startDateTime'] != null) newData['startDateTime'] =
            DateTime.parse(newData['startDateTime']);
        if (newData['star_count'] == null) newData['star_count'] = 0;
        if (newData['like_count'] == null) newData['like_count'] = 0;

        if (newData['uriPreviewId'] != null) {
          // Get the associated URI preview.
          return f
              .child('/uri_previews/${newData['uriPreviewId']}')
              .once('value')
              .then((e) {
            var previewData = e.val();
            UriPreview preview = UriPreview.fromJson(previewData);
            newData['uriPreview'] = preview.toJson();
            newData['uriPreview']['imageSmallLocation'] = (newData['uriPreview']
                        ['imageSmallLocation'] !=
                    null)
                ? '${ config['google']['cloudStoragePath']}/${newData['uriPreview']['imageSmallLocation']}'
                : null;
            newData['uriPreviewTried'] = true;

            // If item's subject/body are empty, use any title/teaser from URI preview instead.
            if (newData['subject'] == null) newData['subject'] = preview.title;
            if (newData['body'] == null) newData['body'] = preview.teaser;
          });
        }
      }).then((_) {
        // Now that new data is pre-processed, update current data.
        newData.forEach((k, v) => currentData[k] = v);
      });
    });

    // Listen for moved (priority order has changed) items.
    childMovedSubscriber = itemsRef.onChildMoved.listen((e) {
      return; // TODO: Don't change position for now.
      var movedItem = e.snapshot.val();

      if (typeFilter == 'event') {
        updateGroupedView();
        // Sort the list by the event's startDateTime.
        items.sort(
            (m1, m2) => m1["startDateTime"].compareTo(m2["startDateTime"]));
      } else {
        var index =
            indexOfClosestItemByDate(DateTime.parse(movedItem['updatedDate']));

        items.insert(
            index == null ? 0 : index, toObservable(processItem(movedItem)));
      }
    });

    // Listen for removed items.
//    childRemovedSubscriber = itemsRef.onChildRemoved.listen((e) {
//      updateEventView();
//      items.removeWhere((i) => i['id'] == e.snapshot.key);
//    });
  }

  // Group items by date group (Today, Tomorrow, etc.) and store in a separate list.
  updateGroupedView() {
    if (typeFilter == 'event' || typeFilter == 'news') {
      groupedItems.clear();
      items.forEach((item) {
        var key = item['dateGroup'];
        if (groupedItems[key] == null) {
          groupedItems[key] = [];
        }
        groupedItems[key].add(item);
      });
    }
  }

  processItem(fb.DataSnapshot snapshot) {
    var item = toObservable(snapshot.val());
    // Make sure we're using the collapsed username.
    item['user'] = (item['user'] as String).toLowerCase();

    UserModel.usernameForDisplay(item['user'], f, app.cache).then(
        (String usernameForDisplay) =>
            item['usernameForDisplay'] = usernameForDisplay);

    // If no updated date, use the created date.
    // TODO: We assume createdDate is never null!
    if (item['updatedDate'] == null) {
      item['updatedDate'] = item['createdDate'];
    }

    // The live-date-time element needs parsed dates.
    item['updatedDate'] = DateTime.parse(item['updatedDate']);
    item['createdDate'] = DateTime.parse(item['createdDate']);

    switch (item['type']) {
      case 'event':
        if (item['startDateTime'] != null) item['startDateTime'] =
            DateTime.parse(item['startDateTime']);
        item['defaultImage'] = 'event';
        break;
      case 'announcement':
        item['defaultImage'] = 'announcement';
        break;
      case 'news':
        item['defaultImage'] = 'custom-icons:news';
        break;
      case 'message':
      case 'other':
        item['type'] = null;
        break;
      default:
    }

    // Handle any URI previews the item may have.
    if (item['uriPreviewId'] != null) {
      f.child('/uri_previews/${item['uriPreviewId']}').onValue.listen((e) {
        var previewData = e.snapshot.val();

        if (previewData == null) return;

        UriPreview preview = UriPreview.fromJson(previewData);
        item['uriPreview'] = preview.toJson();
        item['uriPreview']['imageSmallLocation'] = (item['uriPreview']
                    ['imageSmallLocation'] !=
                null)
            ? '${app.cloudStoragePath}/${item['uriPreview']['imageSmallLocation']}'
            : null;
        item['uriPreviewTried'] = true;

        // If subject and body are empty, use title and teaser from URI preview instead.
        if (item['subject'] == null) item['subject'] = preview.title;
        if (item['body'] == null) item['body'] = preview.teaser;
      });
    } else {
      item['uriPreviewTried'] = true;
    }

    item['formattedBody'] = InputFormatter.createTeaser(item['body'], 75);

    var createdDate = item['createdDate'];
    item['formattedCreatedDate'] = InputFormatter.formatDate(createdDate.toLocal(), direction: 'past');

    // Prepare the domain name.
    if (item['url'] != null && isValidUrl(item['url'])) {
      String uriHost = Uri.parse(item['url']).host;
      String uriHostShortened = (uriHost != null)
          ? uriHost.substring(uriHost
                  .toString()
                  .lastIndexOf(".", uriHost.toString().lastIndexOf(".") - 1) +
              1)
          : null;
      item['uriHost'] = uriHostShortened;
    }

    // If we're filtering for just events, let's also get a date group so we can group events
    // by today, tomorrow, this week, etc.
    if (typeFilter == "event") {
      item['dateGroup'] = DateGroup.getDateGroupName(item['startDateTime']);
    }

    // If we're filtering for just events, let's also get a date group so we can group events
    // by today, tomorrow, this week, etc.
    if (typeFilter == "news") {
      item['dateGroup'] = DateGroup.getDateGroupName(item['createdDate']);
    }

    // Use the Firebase snapshot ID as our ID.
    item['id'] = snapshot.key;

    // Listen for changes to the like count.
    f.child('/items/' + item['id'] + '/like_count').onValue.listen((e) {
      item['like_count'] = (e.snapshot.val() != null) ? e.snapshot.val() : 0;
    });


    listenForLikedState() {
      var likedItemsRef = f.child('/liked_by_user/' +
      app.user.username.toLowerCase() +
      '/items/' +
      item['id']);

      userSubscriptions.add(likedItemsRef.onValue.listen((e) {
        item['liked'] = e.snapshot.val() != null;
      }));
    }

    if (app.user != null) {
      listenForLikedState();
    }

    // If and when we have a user, see if they liked the item.
    app.onUserChanged.listen((UserModel user) {
      if (user == null) {
        item['liked'] = false;
        userSubscriptions.forEach((s) => s.cancel());
        userSubscriptions.clear();
      } else {
        listenForLikedState();
      }
    });

    return item;
  }

  void toggleItemStar(id) {
    if (app.user == null) return app.showMessage(
        "Kindly sign in first.", "important");

    var item = items.firstWhere((i) => i['id'] == id);

    var starredItemRef = f.child('/starred_by_user/' +
        app.user.username.toLowerCase() +
        '/items/' +
        item['id']);
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
      f
          .child('/users_who_starred/item/' +
              item['id'] +
              '/' +
              app.user.username.toLowerCase())
          .remove();
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
      f
          .child('/users_who_starred/item/' +
              item['id'] +
              '/' +
              app.user.username.toLowerCase())
          .set(true);
    }
  }

  void toggleItemLike(id) {
    if (app.user == null) return app.showMessage(
        "Kindly sign in first.", "important");

    var item = items.firstWhere((i) => i['id'] == id);

    var starredItemRef = f.child('/liked_by_user/' +
        app.user.username.toLowerCase() +
        '/items/' +
        item['id']);
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
      f
          .child('/users_who_liked/item/' +
              item['id'] +
              '/' +
              app.user.username.toLowerCase())
          .remove();
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
      f
          .child('/users_who_liked/item/' +
              item['id'] +
              '/' +
              app.user.username.toLowerCase())
          .set(true);
    }
  }

  deleteItem(String id) async {
    await HttpRequest.request(app.serverPath + Routes.deleteItem.reverse([]), method: 'POST',
    sendData: JSON.encode({'id': id, 'authToken': app.authToken}));

    groupedItems.values.forEach((List i) => i.removeWhere((i) => i['id'] == id));
  }

//  void loadUserStarredItemInformation() {
//    items.forEach((item) {
//      if (app.user != null) {
//        var starredItemsRef = f.child('/starred_by_user/' +
//            app.user.username.toLowerCase() +
//            '/items/' +
//            item['id']);
//        starredItemsRef.onValue.listen((e) {
//          item['starred'] = e.snapshot.val() != null;
//        });
//      } else {
//        item['starred'] = false;
//      }
//    });
//  }

  void loadUserLikedItemInformation() {
    if (app.user == null) return;
    items.forEach((item) {
      var starredItemsRef = f.child('/liked_by_user/' +
          app.user.username.toLowerCase() +
          '/items/' +
          item['id']);
      starredItemsRef.onValue.listen((e) {
        item['liked'] = e.snapshot.val() != null;
      });
    });
  }

  void paginate() {
    if (reloadingContent == false && reachedEnd == false) loadItemsByPage();
  }
}
