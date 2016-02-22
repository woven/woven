library main_view_model;

import 'dart:html';
import 'dart:async';

import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart';

import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/util.dart';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/shared/model/community.dart';
import 'feed.dart';
import 'chat.dart';
import 'people.dart';
import 'item.dart';
import 'list.dart';
import 'base.dart';

class MainViewModel extends BaseViewModel with Observable {
  final App app;
  @observable final List communities = toObservable([]);
  final List users = toObservable([]);
  final Map feedViewModels = {};
  final Map itemViewModels = {};
  final Map peopleViewModels = {};
  final Map chatViewModels = {};
  var starredViewModelForUser = null;
  int pageSize = 20;
  @observable bool reloadingContent = false;
  @observable bool reachedEnd = false;
  var snapshotPriority = null;

  List<StreamSubscription> subscriptions = [];

  Firebase get f => app.f;

  MainViewModel(this.app) {
    if (app.debugMode) print('DEBUG: MainViewModel constructed');
    loadCommunities();
  }

  // Get the view model for the item.
  @observable ItemViewModel get itemViewModel {
    var id = null;

    // Always find the item ID from the URL, for now.
    // TODO: If we've already loaded item data into the inboxViewModel, use that?
    String path = window.location.toString();

    if (Uri.parse(path).pathSegments.length == 0 ||
        Uri.parse(path).pathSegments[0] != "item") return null;

    if (Uri.parse(path).pathSegments.length > 1) {
      // Decode the base64 URL and determine the item.
      var encodedItem = Uri.parse(window.location.toString()).pathSegments[1];
      id = base64Decode(encodedItem);
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

  // Get the view model for the people list.
  @observable PeopleViewModel get peopleViewModel {
    var id = "all"; // Just one global people view for now.

    if (id == null) return null; // No item, no view model to use.

    if (!peopleViewModels.containsKey(id)) {
      // Item not stored yet, let's create it and store it.
      var vm = new PeopleViewModel(
          app:
              app); // Maybe pass MainViewModel instance to the child, so there's a way to access the parent. Or maybe pass App. Do as you see fit.
      peopleViewModels[id] = vm; // Store it.
    }

    return peopleViewModels[id];
  }

  // Get the view model for the current inbox.
  @observable FeedViewModel get feedViewModel {
    if (app.debugMode)
      print('feedViewModel getter called // community: ${app.community}');
    if (app.community == null) return null;

    var id = app.community.alias;

    if (id == null) return null; // No item, no view model to use.

    if (!feedViewModels.containsKey(id)) {
      // Item not stored yet, let's create it and store it.
      var vm = new FeedViewModel(
          app:
              app); // Maybe pass MainViewModel instance to the child, so there's a way to access the parent. Or maybe pass App. Do as you see fit.
      feedViewModels[id] = vm; // Store it.
    }

    return feedViewModels[id];
  }

  FeedViewModel get newsViewModel {
    if (app.community == null) return null;

    var id = app.community.alias + '_news';

    if (id == null) return null;

    if (!feedViewModels.containsKey(id)) {
      var vm = new FeedViewModel(app: app, typeFilter: 'news');
      feedViewModels[id] = vm;
    }
    return feedViewModels[id];
  }

  FeedViewModel get eventViewModel {
    if (app.debugMode)
      print(
          'DEBUG: eventViewModel getter called // community: ${app.community}');

    if (app.community == null) return null;
    if (app.community.alias == null) return null;

    var id = app.community.alias + '_events';

    if (app.debugMode) print('DEBUG: vm id: $id');

    if (!feedViewModels.containsKey(id)) {
      var vm = new FeedViewModel(app: app, typeFilter: 'event');
      feedViewModels[id] = vm;
    }
    return feedViewModels[id];
  }

  @observable FeedViewModel get announcementViewModel {
    if (app.community == null) return null;

    var id = app.community.alias + '_announcements';

    if (id == null) return null;

    if (!feedViewModels.containsKey(id)) {
      var vm = new FeedViewModel(app: app, typeFilter: 'announcement');
      feedViewModels[id] = vm;
    }
    return feedViewModels[id];
  }

  // Get the view model for the current inbox.
  ChatViewModel get chatViewModel {
    if (app.community == null) return null;

    var id = app.community.alias;

    if (id == null) return null; // No item, no view model to use.

    if (!chatViewModels.containsKey(id)) {
      // Item not stored yet, let's create it and store it.
      var vm = new ChatViewModel(
          app:
              app); // Maybe pass MainViewModel instance to the child, so there's a way to access the parent. Or maybe pass App. Do as you see fit.
      chatViewModels[id] = vm; // Store it.
    }

    return chatViewModels[id];
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
    var communitiesRef = f.child('/communities').limitToFirst(20);

    // Get the list of communities, and listen for new ones.
    communitiesRef.onChildAdded.listen((e) {
      // Make it observable right from the start.
      CommunityModel community =
          CommunityModel.fromJson(toObservable(e.snapshot.val()));

      community.id = e.snapshot.key;

      if (community.disabled == true) return;
      if (community.id == null) return;

      // Add the community to the app cache, so we have it elsewhere.
      app.cache.communities[community.id] = community;

      // Set some defaults.
      if (community.updatedDate == null)
        community.updatedDate = community.createdDate;
      if (community.starCount == null) community.starCount = 0;

      // The live-date-time element needs parsed dates.
      community.updatedDate = community.updatedDate;
      community.createdDate = community.createdDate;

      // Insert each new community into the list.
      communities.add(community);

      // Sort the list by the item's updatedDate.
      communities.sort((CommunityModel m1, CommunityModel m2) =>
          m2.updatedDate.compareTo(m1.updatedDate));

      listenForStarredState() {
        var starredCommunitiesRef = f.child('/starred_by_user/' +
            app.user.username.toLowerCase() +
            '/communities/' +
            community.id);
        subscriptions.add(starredCommunitiesRef.onValue.listen((e) {
          community.starred = e.snapshot.val() != null;
        }));
      }

      if (app.user != null) {
        listenForStarredState();
      }

      app.onUserChanged.listen((UserModel user) {
        if (user == null) {
          community.starred = false;
          subscriptions.forEach((s) => s.cancel());
          subscriptions.clear();
        } else {
          listenForStarredState();
        }
      });
    });

    // When a community changes, let's update it.
    communitiesRef.onChildChanged.listen((e) {
      CommunityModel community =
          communities.firstWhere((CommunityModel i) => i.id == e.snapshot.key);
      CommunityModel newData = CommunityModel.fromJson(e.snapshot.val());

      community
        ..alias = newData.alias
        ..updatedDate = newData.updatedDate
        ..name = newData.name
        ..shortDescription = newData.shortDescription
        ..starCount = newData.starCount;

      communities.sort((m1, m2) => m2.updatedDate.compareTo(m1.updatedDate));
    });
  }

  void toggleCommunityStar(id) {
    if (app.user == null)
      return app.showMessage("Kindly sign in first.", "important");

    CommunityModel community =
        communities.firstWhere((CommunityModel i) => i.id == id);
    var starredCommunityRef = f.child('/starred_by_user/' +
        app.user.username.toLowerCase() +
        '/communities/' +
        community.id);
    var communityRef = f.child('/communities/' + community.id);

    if (community.starred) {
      // If it's starred, time to unstar it.
      community.starred = false;
      starredCommunityRef.remove();

      app.analytics.sendEvent('Channel', 'leave', label: community.id);

      // Update the star count.
      communityRef.child('/star_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          community.starCount = 0;
          return 0;
        } else {
          community.starCount = currentCount - 1;
          return community.starCount;
        }
      });

      // Update the list of users who starred.
      f
          .child('/users_who_starred/community/' +
              community.id +
              '/' +
              app.user.username.toLowerCase())
          .remove();
    } else {
      // If it's not starred, time to star it.
      community.starred = true;
      starredCommunityRef.set(true);

      app.analytics.sendEvent('Channel', 'join', label: community.alias);

      // Update the star count.
      communityRef.child('/star_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          community.starCount = 1;
          return 1;
        } else {
          community.starCount = currentCount + 1;
          return community.starCount;
        }
      });

      // Update the list of users who starred.
      f
          .child('/users_who_starred/community/' +
              community.id +
              '/' +
              app.user.username.toLowerCase())
          .set(true);
    }
  }
}
