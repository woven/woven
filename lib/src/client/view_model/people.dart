library people_view_model;

import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
import 'base.dart';
import 'dart:async';

class PeopleViewModel extends BaseViewModel with Observable {
  final App app;
  final List users = toObservable([]);
  int pageSize = 40;
  @observable bool reloadingContent = false;
  @observable bool reachedEnd = false;
  var lastPriority = null;
  var topPriority = null;
  var secondToLastPriority = null;

  StreamSubscription childAddedSubscriber, childChangedSubscriber, childMovedSubscriber, childRemovedSubscriber;

  Firebase get f => app.f;

  PeopleViewModel({this.app}) {
    loadUsersByPage();
  }

  /**
   * Get all the users.
   */
  loadUsersByPage() {
    reloadingContent = true;
    int count = 0;

    if (users.length == 0) onLoadCompleter.complete(true);

    var itemsRef = f.child('/users')
    .startAt(priority: lastPriority)
    .limitToFirst(pageSize + 1);

    // Get the list of items, and listen for new ones.
    itemsRef.once('value').then((snapshot) {
      print('===============\nPRIORITY DEBUG: $lastPriority | $secondToLastPriority');

      snapshot.forEach((itemSnapshot) {
        var user = itemSnapshot.val();

        count++;

        // Track the snapshot's priority so we can paginate from the last one.
        lastPriority = itemSnapshot.getPriority();

        // Don't process the extra item we tacked onto pageSize in the limit() above.
        if (count > pageSize) return;

        // Remember the priority of the last item, excluding the extra item which we ignore above.
        secondToLastPriority = itemSnapshot.getPriority();

        // Insert each new item into the list.
        if (!user['disabled']) users.add(toObservable(processItem(itemSnapshot)));
      });

      relistenForItems();

      print(count);

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
    // If this is the first item loaded, start listening for new items.
    var itemsRef = f.child('/users')
    .startAt(priority: startAt)
    .endAt(priority: endAt);

    // Find the index of the user with the closest created date.
    indexOfClosestItemByDate(date) {
      for (var item in users) {
        if ((item['createdDate'] as DateTime).isAfter(date)) return users.indexOf(item);
      }
    }

    // Listen for new items.
    childAddedSubscriber = itemsRef.onChildAdded.listen((e) {
      Map user = e.snapshot.val();

      var existingItem = users.firstWhere((i) => i['username'].toLowerCase() == e.snapshot.key, orElse: () => null);

      print('debug: ${e.snapshot.key} | ${e.snapshot.getPriority()}');

      if (existingItem != null) return;

      if (!user['disabled']) {
        var index = indexOfClosestItemByDate(DateTime.parse(user['createdDate']));
        users.insert(index == null ? 0 : index, toObservable(processItem(e.snapshot)));
      }
    });

    // Listen for changed items.
    childChangedSubscriber = itemsRef.onChildChanged.listen((e) {
      Map currentData = users.firstWhere((i) => i['username'] == e.snapshot.key);
      Map newData = e.snapshot.val();

      newData.forEach((k, v) {
        if (k == "createdDate" || k == "updatedDate" || k == "startDateTime") v = DateTime.parse(v);
        if (k == "star_count") v = (v != null) ? v : 0;
        if (k == "like_count") v = (v != null) ? v : 0;
        if (k == "picture") v = "${app.cloudStoragePath}/$v";

        currentData[k] = v;
      });
    });

    // Listen for moved (priority order has changed) items.
    childMovedSubscriber = itemsRef.onChildMoved.listen((e) {
      // Sort the list by the item's updatedDate.
      users.sort((m1, m2) => m2["updatedDate"].compareTo(m1["updatedDate"]));
    });

    // Listen for removed items.
//    childRemovedSubscriber = itemsRef.onChildRemoved.listen((e) {
//      users.removeWhere((i) => i['id'] == e.snapshot.key);
//    });
  }

  processItem(DataSnapshot snapshot) {
    var user = toObservable(snapshot.val());

    // The live-date-time element needs parsed dates.
    user['createdDate'] = user['createdDate'] != null ? DateTime.parse(user['createdDate']) : new DateTime.now();

    // Assemble the full path of the user's profile picture.
    // TODO: Simplify choosing of original or small.
    if (user['picture'] != null) user['picture'] = "${config['google']['cloudStoragePath']}/${(user['pictureSmall'] != null) ? user['pictureSmall'] : user['picture']}";

    return user;
  }

  void paginate() {
    if (reloadingContent == false && reachedEnd == false) loadUsersByPage();
  }
}