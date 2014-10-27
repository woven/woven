library main_view_model;

import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
import 'feed.dart';
import 'item.dart';
import 'list.dart';

import 'package:crypto/crypto.dart';
import 'dart:convert';

class MainViewModel extends Observable {
  final App app;
  final List communities = toObservable([]);
  final List users = toObservable([]);
  final f = new Firebase(config['datastore']['firebaseLocation']);
  final Map feedViewModels = {};
  final Map itemViewModels = {};
  var starredViewModelForUser = null;
  int pageSize = 20;
  @observable bool reloadingContent = false;
  @observable bool reachedEnd = false;
  var snapshotPriority = null;

  MainViewModel(this.app) {
    loadCommunities();
    loadUsersByPage();
  }

  // Get the view model for the item.
  @observable ItemViewModel get itemViewModel {
    var id = null;

    // Always find the item ID from the URL, for now.
    // TODO: If we've already loaded item data into the inboxViewModel, use that?
    String path = window.location.toString();

    if (Uri.parse(path).pathSegments.length == 0 || Uri.parse(path).pathSegments[0] != "item") return null;

    if (Uri.parse(path).pathSegments.length > 1) {
      // Decode the base64 URL and determine the item.
      var base64 = Uri.parse(window.location.toString()).pathSegments[1];
      var bytes = CryptoUtils.base64StringToBytes(base64);
      var decodedItem = UTF8.decode(bytes);
      id = decodedItem;
    }

    if (id == null) return null; // No item.

    if (!itemViewModels.containsKey(id)) {
      // Item not stored yet, let's create it and store it.
      var vm = new ItemViewModel(app);
      itemViewModels[id] = vm; // Store it.
    }

    // TODO: More checks?

    return itemViewModels[id];
  }

  // Get the view model for the current inbox.
  @observable FeedViewModel get feedViewModel {
    if (app.community == null) return null;

    var id = app.community.alias;

    if (id == null) return null; // No item, no view model to use.

    if (!feedViewModels.containsKey(id)) {
      // Item not stored yet, let's create it and store it.
      var vm = new FeedViewModel(app: app); // Maybe pass MainViewModel instance to the child, so there's a way to access the parent. Or maybe pass App. Do as you see fit.
      feedViewModels[id] = vm; // Store it.
    }
    return feedViewModels[id];
  }

  @observable FeedViewModel get eventViewModel {
    if (app.community == null) return null;

    var id = app.community.alias + '_events';

    if (id == null) return null;

    if (!feedViewModels.containsKey(id)) {
      var vm = new FeedViewModel(app: app, typeFilter: 'event');
      feedViewModels[id] = vm;
    }
    return feedViewModels[id];
  }

  // Get the view model for the user's starred items.
  @observable StarredViewModel get starredViewModel {
    if (app.user == null) return null; // No user, no starred view model.
    if (starredViewModelForUser == null) {
      // Item not stored yet, let's create it and store it.
      var vm = new StarredViewModel(app);
      starredViewModelForUser = vm; // Store it.
    }
    return starredViewModelForUser;
  }

  /**
   * Load the communities and listen for changes.
   */
  void loadCommunities() {
    // TODO: Remove the limit.
    var communitiesRef = f.child('/communities').limit(20);

     // Get the list of communities, and listen for new ones.
    communitiesRef.onChildAdded.listen((e) {
      // Make it observable right from the start.
      var community = toObservable(e.snapshot.val());

      if (community['disabled'] == true) return;

      // Use the ID from Firebase as our ID.
      community['id'] = e.snapshot.name;

      // Set some defaults.
      if (community['updatedDate'] == null) community['updatedDate'] = community['createdDate'];
      if (community['star_count'] == null)  community['star_count'] = 0;


      // The live-date-time element needs parsed dates.
      community['updatedDate'] = DateTime.parse(community['updatedDate']);
      community['createdDate'] = DateTime.parse(community['createdDate']);

      // Insert each new community into the list.
      communities.add(community);

      // Sort the list by the item's updatedDate.
      communities.sort((m1, m2) => m2["updatedDate"].compareTo(m1["updatedDate"]));

      if (app.user != null) {
        var starredCommunitiesRef = f.child('/starred_by_user/' + app.user.username + '/communities/' + community['id']);
        starredCommunitiesRef.onValue.listen((e) {
          community['starred'] = e.snapshot.val() != null;
        });
      } else {
        community['starred'] = false;
      }
    });

    // When a community changes, let's update it.
    communitiesRef.onChildChanged.listen((e) {
      Map currentData = communities.firstWhere((i) => i['id'] == e.snapshot.name);
      Map newData = e.snapshot.val();

      newData.forEach((k, v) {
        if (k == "createdDate" || k == "updatedDate") v = DateTime.parse(v);
        if (k == "star_count") v = (v != null) ? v : 0;

        currentData[k] = v;
      });

      communities.sort((m1, m2) => m2["updatedDate"].compareTo(m1["updatedDate"]));
    });
  }

  void toggleCommunityStar(id) {
    if (app.user == null) return app.showMessage("Kindly sign in first.", "important");

    //    app.showMessage("Stars aren't working well yet. :)");

    var community = communities.firstWhere((i) => i['id'] == id);


    var starredCommunityRef = f.child('/starred_by_user/' + app.user.username + '/communities/' + community['id']);
    var communityRef = f.child('/communities/' + community['id']);

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
      f.child('/users_who_starred/community/' + community['id'] + '/' + app.user.username).remove();
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
      f.child('/users_who_starred/community/' + community['id'] + '/' + app.user.username).set(true);
    }
  }

  /**
   * Get all the users.
   */
  loadUsersByPage() {
    reloadingContent = true;

    var itemsRef = f.child('/users').startAt(priority: snapshotPriority).limit(pageSize + 1);
    int count = 0;

    // Get the list of items, and listen for new ones.
    itemsRef.once('value').then((snapshot) {
      snapshot.forEach((itemSnapshot) {
        count++;
        // Don't process the extra item we tacked onto pageSize in the limit() above.
        if (count > pageSize) return;

        var user = itemSnapshot.val();

        // The live-date-time element needs parsed dates.
        user['createdDate'] = user['createdDate'] != null ? DateTime.parse(user['createdDate']) : new DateTime.now();

        if (user['disabled'] == true) return;

        // Insert each new item into the list.
        users.add(user);

        // Track the snapshot's priority so we can paginate from the last one.
        snapshotPriority = itemSnapshot.getPriority();
      });

      if (count < pageSize) reachedEnd = true;
      reloadingContent = false;
    });
  }

  /**
   * Whenever user signs in/out, we should call this to trigger any necessary updates.
   */
  void invalidateUserState() {
    loadUserStarredCommunityInformation();

    if (itemViewModel != null) {
      itemViewModel.loadItemUserStarredLikedInformation();
    }

    if (app.community != null) {
      feedViewModel.loadUserStarredItemInformation();
      feedViewModel.loadUserLikedItemInformation();
    }

    if (app.user != null) {
      starredViewModel.loadStarredItemsForUser();
    }
    // Add more cases later as we need.
  }

  void loadUserStarredCommunityInformation() {
    communities.forEach((community) {
      if (app.user != null) {
        var starredCommunityRef = f.child('/starred_by_user/' + app.user.username + '/communities/' + community['id']);
        starredCommunityRef.onValue.listen((e) {
          community['starred'] = e.snapshot.val() != null;
        });
      } else {
        community['starred'] = false;
      }
    });
  }

  void paginateUsers() {
    if (reloadingContent == false && reachedEnd == false) loadUsersByPage();
  }
}
