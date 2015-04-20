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
  int pages = 0;
  @observable bool isLoading = false;
  @observable bool reachedEnd = false;
  var lastPriority = null;
  var topPriority = null;
  var secondToLastPriority = null;

  StreamSubscription childAddedSubscriber, childChangedSubscriber, childMovedSubscriber, childRemovedSubscriber;

  Firebase get f => app.f;

  PeopleViewModel({this.app}) {
    loadPage();
  }

  loadPage() {
    isLoading = true;
    if ((users.length - 1) > (pageSize * pages)) return;
    pages++;

    var queryRef = f.child('/users')
      .orderByPriority()
      .startAt(priority: lastPriority)
      .limitToFirst(pageSize + 1);

    // If we count any less than one more beyond the current page, we've reached the end.
    int count = 0;
    queryRef.once('value').then((results) {
      results.forEach((i) => count++ );
      if (count <= pageSize) reachedEnd = true;
      isLoading = false;
    });

    queryRef.onChildAdded.listen((e) {
      var user = e.snapshot.val();
      lastPriority = e.snapshot.getPriority();
      var existingItem = users.firstWhere((i) => (i['username'] as String).toLowerCase() == e.snapshot.key, orElse: () => null);

      if (existingItem == null && !user['disabled']) {
        // The live-date-time element needs parsed dates.
        user['createdDate'] = user['createdDate'] != null ? DateTime.parse(user['createdDate']) : new DateTime.now();

        // Assemble the full path of the user's profile picture.
        // TODO: Simplify choosing of original or small.
        if (user['picture'] != null) user['picture'] = "${config['google']['cloudStoragePath']}/${(user['pictureSmall'] != null) ? user['pictureSmall'] : user['picture']}";

        users.add(user); // Add to list.
      }
    });
  }

  void paginate() {
    if (isLoading == false && reachedEnd == false) loadPage();
  }
}