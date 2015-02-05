library feed_view_model;

import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/date_group.dart';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'dart:async';
import 'base.dart';

class FeedViewModel extends BaseViewModel with Observable {
  final App app;
  final List items = toObservable([]);
  final Map groupedItems = toObservable({});

  final f = new Firebase(config['datastore']['firebaseLocation']);
  String dataLocation = '';
  @observable String typeFilter;

  int pageSize = 20;
  @observable bool reloadingContent = false;
  @observable bool reachedEnd = false;
  var lastPriority = null;
  var topPriority = null;
  var secondToLastPriority = null;

  StreamSubscription childAddedSubscriber, childChangedSubscriber, childMovedSubscriber, childRemovedSubscriber;

  FeedViewModel({this.app, this.typeFilter}) {

    if (typeFilter == 'event') {
      var now = new DateTime.now();
      DateTime startOfToday = new DateTime(now.year, now.month, now.day);
      topPriority = lastPriority = startOfToday.millisecondsSinceEpoch;
    } else {
      topPriority == null;
    }

    loadItemsByPage();
  }

  /**
   * Load more items pageSize at a time.
   */
  loadItemsByPage() {
    reloadingContent = true;
    int count = 0;

    if (typeFilter != null) {
      dataLocation = '/items_by_community_by_type/' + app.community.alias + '/' + typeFilter;
    } else {
      dataLocation = '/items_by_community/' + app.community.alias;
    }

    var itemsRef = f.child(dataLocation)
      .startAt(priority: lastPriority)
      .limit(pageSize + 1);

    if (items.length == 0) onLoadCompleter.complete(true);

    // Get the list of items, and listen for new ones.
    itemsRef.once('value').then((snapshot) {
      snapshot.forEach((itemSnapshot) {
        count++;

        // Track the snapshot's priority so we can paginate from the last one.
        lastPriority = itemSnapshot.getPriority();

        // Don't process the extra item we tacked onto pageSize in the limit() above.
        if (count > pageSize) return;

        // Remember the priority of the last item, excluding the extra item which we ignore above.
        secondToLastPriority = itemSnapshot.getPriority();

        // Insert each new item into the list.
        // TODO: This seems weird. I do it so I can separate out the method for adding to the list.
        items.add(toObservable(processItem(itemSnapshot)));
      });

      updateEventView();

      relistenForItems();

      // If we received less than we tried to load, we've reached the end.
      if (count <= pageSize) reachedEnd = true;
      reloadingContent = false;
    });
  }

  /**
   * Listen for new stuff within the items we're currently showing.
   */
  void relistenForItems() {
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

    listenForNewItems(startAt: topPriority, endAt: secondToLastPriority);
  }

  listenForNewItems({startAt, endAt}) {
    if (typeFilter != null) {
      dataLocation = '/items_by_community_by_type/' + app.community.alias + '/' + typeFilter;
    } else {
      dataLocation = '/items_by_community/' + app.community.alias;
    }

    // Find the index of the item with the closest updated date.
    indexOfClosestItemByDate(date) {
      for (var item in items) {
        if ((item['updatedDate'] as DateTime).isAfter(date)) return items.indexOf(item);
      }
    }

    // If this is the first item loaded, start listening for new items.
    var itemsRef = f.child(dataLocation)
      .startAt(priority: startAt)
      .endAt(priority: endAt);

    // Listen for new items.
    childAddedSubscriber = itemsRef.onChildAdded.listen((e) {
      Map newItem = e.snapshot.val();
      var existingItem = items.firstWhere((i) => i['id'] == e.snapshot.name, orElse: () => null);
      if (existingItem != null) return;

      var index = indexOfClosestItemByDate(DateTime.parse(newItem['updatedDate']));

      items.insert(index == null ? 0 : index, toObservable(processItem(e.snapshot)));

      if (typeFilter == 'event') {
        // Sort the list by the event's startDateTime.
        items.sort((m1, m2) => m1["startDateTime"].compareTo(m2["startDateTime"]));
        updateEventView();
      }
    });

    // Listen for changed items.
    childChangedSubscriber = itemsRef.onChildChanged.listen((e) {
      Map currentData = items.firstWhere((i) => i['id'] == e.snapshot.name);
      Map newData = e.snapshot.val();

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
            newData['uriPreview']['imageSmallLocation'] = (newData['uriPreview']['imageSmallLocation'] != null) ? '${config['google']['cloudStoragePath']}/${newData['uriPreview']['imageSmallLocation']}' : null;
//            newData['uriPreviewTried'] = true;

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
        updateEventView();
        // Sort the list by the event's startDateTime.
        items.sort((m1, m2) => m1["startDateTime"].compareTo(m2["startDateTime"]));
      } else {
        var index = indexOfClosestItemByDate(DateTime.parse(movedItem['updatedDate']));

        items.insert(index == null ? 0 : index, toObservable(processItem(e.snapshot)));
      }
    });

    // Listen for removed items.
//    childRemovedSubscriber = itemsRef.onChildRemoved.listen((e) {
//      updateEventView();
//      items.removeWhere((i) => i['id'] == e.snapshot.name);
//    });
  }

  // Group items by date group (Today, Tomorrow, etc.) and store in a separate list.
  updateEventView() {
    if (typeFilter == 'event') {
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

  processItem(DataSnapshot snapshot) {
    var item = toObservable(snapshot.val());

    // If no updated date, use the created date.
    if (item['updatedDate'] == null) {
      item['updatedDate'] = item['createdDate'];
    }

    // The live-date-time element needs parsed dates.
    item['updatedDate'] = DateTime.parse(item['updatedDate']);
    item['createdDate'] = DateTime.parse(item['createdDate']);

    switch (item['type']) {
      case 'event':
        if (item['startDateTime'] != null) item['startDateTime'] = DateTime.parse(item['startDateTime']);
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
        UriPreview preview = UriPreview.fromJson(previewData);
        item['uriPreview'] = preview.toJson();
        item['uriPreview']['imageSmallLocation'] = (item['uriPreview']['imageSmallLocation'] != null) ? '${config['google']['cloudStoragePath']}/${item['uriPreview']['imageSmallLocation']}' : null;
        item['uriPreviewTried'] = true;

        // If subject and body are empty, use title and teaser from URI preview instead.
        if (item['subject'] == null) item['subject'] = preview.title;
        if (item['body'] == null) item['body'] = preview.teaser;
      });
    } else {
      item['uriPreviewTried'] = true;
    }

    // Prepare the domain name.
    if (item['url'] != null && isValidUrl(item['url'])) {
      String uriHost = Uri.parse(item['url']).host;
      String uriHostShortened = (uriHost != null) ? uriHost.substring(uriHost.toString().lastIndexOf(".", uriHost.toString().lastIndexOf(".") - 1) + 1) : null;
      item['uriHost'] = uriHostShortened;
    }

    // If we're filtering for just events, let's also get a date group so we can group events
    // by today, tomorrow, this week, etc.
    if (typeFilter == "event") {
      item['dateGroup'] = DateGroup.getDateGroupName(item['startDateTime']);
    }

    // Use the Firebase snapshot ID as our ID.
    item['id'] = snapshot.name;

    // Sort the list by the item's updatedDate.
//      items.sort((m1, m2) => m2["updatedDate"].compareTo(m1["updatedDate"]));

    // Listen for realtime changes to the star count.
    f.child('/items/' + item['id'] + '/star_count').onValue.listen((e) {
      item['star_count'] = (e.snapshot.val() != null) ? e.snapshot.val() : 0;
    });

    // Listen for realtime changes to the like count.
    f.child('/items/' + item['id'] + '/like_count').onValue.listen((e) {
      item['like_count'] = (e.snapshot.val() != null) ? e.snapshot.val() : 0;
    });

    if (app.user != null) {
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

    return item;
  }

  void toggleItemStar(id) {
    if (app.user == null) return app.showMessage("Kindly sign in first.", "important");

    var item = items.firstWhere((i) => i['id'] == id);

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

  void toggleItemLike(id) {
    if (app.user == null) return app.showMessage("Kindly sign in first.", "important");

    var item = items.firstWhere((i) => i['id'] == id);

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

  void loadUserStarredItemInformation() {
    items.forEach((item) {
      if (app.user != null) {
        var starredItemsRef = f.child('/starred_by_user/' + app.user.username + '/items/' + item['id']);
        starredItemsRef.onValue.listen((e) {
          item['starred'] = e.snapshot.val() != null;
        });
      } else {
        item['starred'] = false;
      }

    });
  }

  void loadUserLikedItemInformation() {
    items.forEach((item) {
      if (app.user != null) {
        var starredItemsRef = f.child('/liked_by_user/' + app.user.username + '/items/' + item['id']);
        starredItemsRef.onValue.listen((e) {
          item['liked'] = e.snapshot.val() != null;
        });
      } else {
        item['liked'] = false;
      }
    });
  }

  void paginate() {
    if (reloadingContent == false && reachedEnd == false) loadItemsByPage();
  }
}