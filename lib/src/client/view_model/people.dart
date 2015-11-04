library people_view_model;

import 'dart:async';

import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart';

import 'base.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';

class PeopleViewModel extends BaseViewModel with Observable {
  final App app;
  final List items = toObservable([]);

  int pageSize = 30;
  @observable bool reloadingContent = false;
  @observable bool reachedEnd = false;
  var lastPriority = null;
  var topPriority = null;
  var secondToLastPriority = null;

  StreamSubscription childAddedSubscriber, childChangedSubscriber, childMovedSubscriber, childRemovedSubscriber;

  Firebase get f => app.f;

  PeopleViewModel({this.app}) {
    loadPage();
  }

  loadPage() async {
    reloadingContent = true;
    int count = 0;

    var queryRef = f.child('/users')
      .orderByChild('_priority')
      .startAt(value: lastPriority)
      .endAt(value: -1)
      .limitToFirst(pageSize + 1);

    queryRef.once('value').then((snapshot) {
      if (app.debugMode) print('DEBUG: itemRef.once called');
      snapshot.forEach((itemSnapshot) {
        count++;
        Map item = itemSnapshot.val();

        // Use the Firebase snapshot ID as our ID.
        item['id'] = itemSnapshot.key;

        // Track the snapshot's priority so we can paginate from the last one.
        lastPriority = item['_priority'];

        if (app.debugMode) print(
            'DEBUG: $count // key: ${itemSnapshot.key} // lastPriority: ${lastPriority}');

        // Don't process the extra item we tacked onto pageSize in the limit() above.
        if (count > pageSize) return;

        // Remember the priority of the last item, excluding the extra item which we ignore above.
          secondToLastPriority = item['_priority'];

        // Insert each new item into the list.
        items.add(toObservable(processItem(item)));
      });

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

    // Find the index of the item with the closest createdDate.
    indexOfClosestItemByDate(date) {
      for (var item in items) {
        if ((item['createdDate'] as DateTime).isAfter(date)) return items
        .indexOf(item);
      }
    }

    // If this is the first item loaded, start listening for new items.
    var queryRef = f.child('/users')
    .orderByChild('_priority')
    .startAt(value: startAt)
    .endAt(value: endAt);

    // Listen for new items.
    childAddedSubscriber = queryRef.onChildAdded.listen((e) {
      Map newItem = e.snapshot.val();

      if (app.debugMode) print('DEBUG: Child added: ${e.snapshot.key}');

      var existingItem = items.firstWhere((i) => i['id'] == e.snapshot.key,
      orElse: () => null);

      if (existingItem != null) return;

      var index;
        index =
        indexOfClosestItemByDate(DateTime.parse(newItem['createdDate']));

      items.insert(
          index == null ? 0 : index, toObservable(processItem(newItem)));
    });
  }

  Map processItem(Map item) {
    // The live-date-time element needs parsed dates.
    item['createdDate'] = item['createdDate'] != null ? DateTime.parse(item['createdDate']) : new DateTime.now();

    // Assemble the full path of the user's profile picture.
    // TODO: Simplify choosing of original or small.
    if (item['picture'] != null) item['picture'] = "${config['google']['cloudStoragePath']}/${(item['pictureSmall'] != null) ? item['pictureSmall'] : item['picture']}";

    return item;
  }

  void paginate() {
    if (reloadingContent == false && reachedEnd == false) loadPage();
  }
}