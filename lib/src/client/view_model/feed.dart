library feed_view_model;

import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/date_group.dart';
import 'dart:async';

class FeedViewModel extends Observable {
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
  bool isFirstRun = true;

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

    if (typeFilter == "event") {
      dataLocation = '/items_by_community_by_type/' + app.community.alias + '/' + typeFilter;
    } else {
      dataLocation = '/items_by_community/' + app.community.alias;
    }

    var itemsRef = f.child(dataLocation)
      .startAt(priority: lastPriority)
      .limit(pageSize + 1);

    // Get the list of items, and listen for new ones.
    itemsRef.once('value').then((snapshot) {
      snapshot.forEach((itemSnapshot) {
        count++;

        // Track the snapshot's priority so we can paginate from the last one.
        lastPriority = itemSnapshot.getPriority();

        // Don't process the extra item we tacked onto pageSize in the limit() above.
        if (count > pageSize) return;

        // Insert each new item into the list.
        // TODO: This seems weird. I do it so I can separate out the method for adding to the list.
        items.add(toObservable(processItem(itemSnapshot)));
      });

      updateEventView();

      // TODO: Ensure this listener ignores the extra item tacked onto pageSize above.
      relistenForItems();

      // If we received less than we tried to load, we've reached the end.
      if (count <= pageSize) reachedEnd = true;
      reloadingContent = false;
    });
  }

  // TODO: Improve.
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

    listenForNewItems(startAt: topPriority, endAt: lastPriority);
  }

  listenForNewItems({startAt, endAt}) {
    if (typeFilter == "event") {
      dataLocation = '/items_by_community_by_type/' + app.community.alias + '/' + typeFilter;
    } else {
      dataLocation = '/items_by_community/' + app.community.alias;
    }

    // If this is the first item loaded, start listening for new items.
    var itemsRef = f.child(dataLocation)
      .startAt(priority: startAt)
      .endAt(priority: endAt);

    // Listen for new items.
    childAddedSubscriber = itemsRef.onChildAdded.listen((e) {
      items.removeWhere((i) => i['id'] == e.snapshot.name);
      items.add(toObservable(processItem(e.snapshot)));

      if (typeFilter == 'event') {
        updateEventView();
        // Sort the list by the event's startDateTime.
        items.sort((m1, m2) => m1["startDateTime"].compareTo(m2["startDateTime"]));
      } else {
        // Sort the list by the item's updatedDate.
        items.sort((m1, m2) => m2["updatedDate"].compareTo(m1["updatedDate"]));
      }
    });

    // Listen for changed items.
    childChangedSubscriber = itemsRef.onChildChanged.listen((e) {
      Map currentData = items.firstWhere((i) => i['id'] == e.snapshot.name);
      Map newData = e.snapshot.val();

      newData.forEach((k, v) {
        if (k == "createdDate" || k == "updatedDate" || k == "startDateTime") v = DateTime.parse(v);
        if (k == "star_count") v = (v != null) ? v : 0;
        if (k == "like_count") v = (v != null) ? v : 0;

        currentData[k] = v;
      });
    });

    // Listen for moved (priority order has changed) items.
    childMovedSubscriber = itemsRef.onChildMoved.listen((e) {
      if (typeFilter == 'event') {
        updateEventView();
        // Sort the list by the event's startDateTime.
        items.sort((m1, m2) => m1["startDateTime"].compareTo(m2["startDateTime"]));
      } else {
        // Sort the list by the item's updatedDate.
        items.sort((m1, m2) => m2["updatedDate"].compareTo(m1["updatedDate"]));
      }
    });

    // Listen for removed items.
    childRemovedSubscriber = itemsRef.onChildRemoved.listen((e) {
      updateEventView();
      items.removeWhere((i) => i['id'] == e.snapshot.name);
    });
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
        break;
      default:
    }

    // If we're filtering for just events, let's also get a date group so we can group events
    // by today, tomorrow, this week, etc.
    if (typeFilter == "event") {
      item['dateGroup'] = DateGroup.getDateGroupName(item['startDateTime']);

//      if (!itemsByGroupDate.contains(item['dateGroup'])) {
//        print("Does NOT");
//        itemsByGroupDate.add(dateGroup);
//      } else {
//        print("DOES");
//      }
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
    print("Paginating...");
    if (reloadingContent == false && reachedEnd == false) loadItemsByPage();
  }
}