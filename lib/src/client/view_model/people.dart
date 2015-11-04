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
  int pageSize = 20;
  int pages = 0;
  @observable bool isLoading = false;
  @observable bool reachedEnd = false;
  var lastPriority = null;

  StreamSubscription childAddedSubscriber, childChangedSubscriber, childMovedSubscriber, childRemovedSubscriber;

  Firebase get f => app.f;

  PeopleViewModel({this.app}) {
    loadPage();
  }

  loadPage() async {
    isLoading = true;
    if ((items.length - 1) > (pageSize * pages)) return;
    pages++;

    var queryRef = f.child('/users')
      .orderByChild('_priority')
      .startAt(value: lastPriority)
      .endAt(value: 0)
      .limitToFirst(pageSize + 1);

    // If we count any less than one more beyond the current page, we've reached the end.
    var results = await queryRef.once('value');
    int count = results.numChildren;
    if (count <= pageSize) reachedEnd = true;
    isLoading = false;

    // Find the index of the item with the closest updated date.
    indexOfClosestItemByDate(DateTime date) {
      for (var item in items.reversed) {
        if ((item['createdDate'] as DateTime).isAfter(date)) return items.indexOf(item);
      }
    }

    queryRef.onChildAdded.listen((e) {
      var item = e.snapshot.val();
      lastPriority = item['_priority'];
      var existingItem = items.firstWhere((i) => (i['username'] as String).toLowerCase() == e.snapshot.key, orElse: () => null);

      if (existingItem == null && !item['disabled']) {
        // The live-date-time element needs parsed dates.
        item['createdDate'] = item['createdDate'] != null ? DateTime.parse(item['createdDate']) : new DateTime.now();

        // Assemble the full path of the user's profile picture.
        // TODO: Simplify choosing of original or small.
        if (item['picture'] != null) item['picture'] = "${config['google']['cloudStoragePath']}/${(item['pictureSmall'] != null) ? item['pictureSmall'] : item['picture']}";

        var index = indexOfClosestItemByDate(item['createdDate']);

        items.insert(index == null ? 0 : index + 1, item);
      }
    });
  }

  void paginate() {
    if (isLoading == false && reachedEnd == false) loadPage();
  }
}