library main_view_model;

import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
//import 'item.dart';
import 'inbox.dart';

class MainViewModel extends Observable {
  final App app;
  final List communities = toObservable([]);
  final List users = toObservable([]);
  final String firebaseLocation = config['datastore']['firebaseLocation'];
//  final Map itemViewModels = {};
  final Map inboxViewModels = {};

  MainViewModel(this.app) {
    loadCommunities();
    loadUsers();
  }

  // TODO: In progress, unused.
//  @observable ItemViewModel get itemViewModel {
//    var id = app.selectedItem;
//    if (id == null) return null; // No item, no view model to use.
//    if (!itemViewModels.containsKey(id)) {
//      // Item not stored yet, let's create it and store it.
//      var vm = new ItemViewModel(app); // Maybe pass MainViewModel instance to the child, so there's a way to access the parent. Or maybe pass App. Do as you see fit.
//      itemViewModels[id] = vm; // Store it.
//    }
//    return itemViewModels[id];
//  }

  @observable InboxViewModel get inboxViewModel { // Get the current inbox view model.
    var id = app.community.id;
    if (id == null) return null; // No item, no view model to use.
    if (!inboxViewModels.containsKey(id)) {
      // Item not stored yet, let's create it and store it.
      var vm = new InboxViewModel(app); // Maybe pass MainViewModel instance to the child, so there's a way to access the parent. Or maybe pass App. Do as you see fit.
      inboxViewModels[id] = vm; // Store it.
    }
    return inboxViewModels[id];
  }

/**
   * Loads the communities.
   */
  void loadCommunities() {
    var fb = new db.Firebase(firebaseLocation);
    var communityRef = fb.child('/communities');

    // TODO: Undo the limit of 20; https://github.com/firebase/firebase-dart/issues/8
    communityRef.limit(20).onChildAdded.listen((e) {
      // Make it observable right from the start.
      var community = toObservable(e.snapshot.val());

      // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location",
      // so we'll add that to our local item list.
      community['id'] = e.snapshot.name();

      // Set some defaults.
      if (community['updatedDate'] == null) community['updatedDate'] = community['createdDate'];
      if (community['star_count'] == null)  community['star_count'] = 0;

      // The live-date-time element needs parsed dates.
      community['updatedDate'] = DateTime.parse(community['updatedDate']);
      community['createdDate'] = DateTime.parse(community['createdDate']);

      // Insert each new community into the list.
      communities.add(community);

      // Sort the list by the item's updatedDate, then reverse it.
//      communities.sort((m1, m2) => m1["updatedDate"].compareTo(m2["updatedDate"]));
//      communities = toObservable(communities.reversed.toList());

      // Listen for realtime changes to the star count.
      communityRef.child(community['alias'] + '/star_count').onValue.listen((e) {
        community['star_count'] = e.snapshot.val();
      });
    });
  }

  void toggleCommunityStar(id) {
    if (app.user == null) return app.showMessage("Kindly sign in first.", "important");

    //    app.showMessage("Stars aren't working well yet. :)");

    var community = communities.firstWhere((i) => i['id'] == id);

    var firebaseRoot = new db.Firebase(firebaseLocation);
    var starredCommunityRef = firebaseRoot.child('/starred_by_user/' + app.user.username + '/communities/' + community['id']);
    var communityRef = firebaseRoot.child('/communities/' + community['id']);

    if (community['starred']) {
      // If it's starred, time to unstar it.
      community['starred'] = false;
      starredCommunityRef.remove();

      // Update the star count.
      communityRef.child('/star_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          community['star_count'] = 0;
          return 0;
        } else {
          community['star_count'] = currentCount - 1;
          return community['star_count'];
        }
      });

      // Update the list of users who starred.
      firebaseRoot.child('/users_who_starred/community/' + app.community.alias + '/' + app.user.username).remove();
    } else {
      // If it's not starred, time to star it.
      community['starred'] = true;
      starredCommunityRef.set(true);

      // Update the star count.
      communityRef.child('/star_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          community['star_count'] = 1;
          return 1;
        } else {
          community['star_count'] = currentCount + 1;
          return community['star_count'];
        }
      });

      // Update the list of users who starred.
      firebaseRoot.child('/users_who_starred/community/' + app.community.alias + '/' + app.user.username).set(true);
    }
  }

  // TODO: In progress. Need to move item loading to ViewModel.
  void toggleItemStar(id) {
    if (app.user == null) return app.showMessage("Kindly sign in first.", "important");

    //    app.showMessage("Stars aren't working well yet. :)");

    var community = communities.firstWhere((i) => i['id'] == id);

    var firebaseRoot = new db.Firebase(firebaseLocation);
    var starredCommunityRef = firebaseRoot.child('/starred_by_user/' + app.user.username + '/communities/' + community['id']);
    var communityRef = firebaseRoot.child('/communities/' + community['id']);

    if (community['starred']) {
      // If it's starred, time to unstar it.
      community['starred'] = false;
      starredCommunityRef.remove();

      // Update the star count.
      communityRef.child('/star_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          community['star_count'] = 0;
          return 0;
        } else {
          community['star_count'] = currentCount - 1;
          return community['star_count'];
        }
      });

      // Update the list of users who starred.
      firebaseRoot.child('/users_who_starred/community/' + app.community.alias + '/' + app.user.username).remove();
    } else {
      // If it's not starred, time to star it.
      community['starred'] = true;
      starredCommunityRef.set(true);

      // Update the star count.
      communityRef.child('/star_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          community['star_count'] = 1;
          return 1;
        } else {
          community['star_count'] = currentCount + 1;
          return community['star_count'];
        }
      });

      // Update the list of users who starred.
      firebaseRoot.child('/users_who_starred/community/' + app.community.alias + '/' + app.user.username).set(true);
    }
  }





  loadUsers() {
    var f = new db.Firebase(firebaseLocation + '/users');

    // TODO: Undo the limit of 20; https://github.com/firebase/firebase-dart/issues/8
    f.onChildAdded.listen((e) {
      var user = e.snapshot.val();

//      if (user['createdDate'] == null) {
//        // Some temporary code that stored a createdDate where this was none.
//        // It's safe to leave active as it only affects an empty createdDate.
//        DateTime newDate = new DateTime.utc(2014, DateTime.AUGUST, 21, 12);
//        var temp = new db.Firebase(firebaseLocation + "/users/${user['username']}");
//        temp.update({'createdDate': newDate});
//        user['createdDate'] = newDate;
//      }

      // The live-date-time element needs parsed dates.
      user['createdDate'] = user['createdDate'] != null ? DateTime.parse(user['createdDate']) : new DateTime.now();

      // Insert each new item into the list.
      users.add(user);
    });

//    lastUsersQuery.onChildChanged.listen((e) {
//      var item = e.snapshot.val();
//
//      // If no updated date, use the created date.
//      if (person['updatedDate'] == null) {
//        item['updatedDate'] = item['createdDate'];
//      }
//
//      item['updatedDate'] = DateTime.parse(item['updatedDate']);
//
//      // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location"
//      // So we'll add that to our local item list.
//      item['id'] = e.snapshot.name();
//
//      // Insert each new item into the list.
//      items.removeWhere((oldItem) => oldItem['id'] == e.snapshot.name());
//      items.add(item);
//
//      // Sort the list by the item's updatedDate, then reverse it.
//      items.sort((m1, m2) => m1["updatedDate"].compareTo(m2["updatedDate"]));
//      items = items.reversed.toList();
//    });
  }

  /**
   * Whenever user signs in / out, we should call this to trigger any necessary updates.
   */
  void invalidateUserState() {
    loadUserStarredCommunityInformation();
    // Add more cases later as you need...
  }

  void loadUserStarredCommunityInformation() {
    communities.forEach((community) {
      if (app.user != null) {
        var starredCommunityRef = new db.Firebase(firebaseLocation + '/starred_by_user/' + app.user.username + '/communities/' + community['id']);
        starredCommunityRef.onValue.listen((e) {
          community['starred'] = e.snapshot.val() != null;
        });
      } else {
        community['starred'] = false;
      }
    });
  }
}
