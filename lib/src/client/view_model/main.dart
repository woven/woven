library main_view_model;

import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/shared_util.dart';
import 'feed.dart';
import 'chat.dart';
import 'people.dart';
import 'item.dart';
import 'list.dart';
import 'base.dart';

import 'package:woven/src/shared/model/community.dart';

class MainViewModel extends BaseViewModel with Observable {
  final App app;
  final List communities = toObservable([]);
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

    if (Uri.parse(path).pathSegments.length == 0 || Uri.parse(path).pathSegments[0] != "item") return null;

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
      var vm = new PeopleViewModel(app: app); // Maybe pass MainViewModel instance to the child, so there's a way to access the parent. Or maybe pass App. Do as you see fit.
      peopleViewModels[id] = vm; // Store it.
    }

    return peopleViewModels[id];
  }

  // Get the view model for the current inbox.
  @observable FeedViewModel get feedViewModel {
    if (app.debugMode) print('feedViewModel getter called // community: ${app.community}');
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

  @observable FeedViewModel get newsViewModel {
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
    if (app.debugMode) print('DEBUG: eventViewModel getter called // community: ${app.community}');

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
      var vm = new ChatViewModel(app: app); // Maybe pass MainViewModel instance to the child, so there's a way to access the parent. Or maybe pass App. Do as you see fit.
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
      var community = toObservable(e.snapshot.val());

      if (community['disabled'] == true) return;

      // Use the ID from Firebase as our ID.
      community['id'] = e.snapshot.key;

      // Add the community to the app cache, so we have it elsewhere.
      app.cache.communities[community['id']] = CommunityModel.fromJson(community);

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
        var starredCommunitiesRef = f.child('/starred_by_user/' + app.user.username.toLowerCase() + '/communities/' + community['id']);
        starredCommunitiesRef.onValue.listen((e) {
          community['starred'] = e.snapshot.val() != null;
        });
      } else {
        community['starred'] = false;
      }
    });

    // When a community changes, let's update it.
    communitiesRef.onChildChanged.listen((e) {
      Map currentData = communities.firstWhere((i) => i['id'] == e.snapshot.key);
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

    var community = communities.firstWhere((i) => i['id'] == id);
    var starredCommunityRef = f.child('/starred_by_user/' + app.user.username.toLowerCase() + '/communities/' + community['id']);
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
      f.child('/users_who_starred/community/' + community['id'] + '/' + app.user.username.toLowerCase()).remove();

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
      f.child('/users_who_starred/community/' + community['id'] + '/' + app.user.username.toLowerCase()).set(true);
    }
  }

  /**
   * Whenever user signs in/out, we should call this to trigger any necessary updates.
   */
  void invalidateUserState() {
    loadUserStarredCommunityInformation();

    if (itemViewModel != null) {
      itemViewModel.loadItemUserStarredLikedInformation();
    }

    // TODO: This is causing feedViewModel to load even if we loaded an eventViewModel.
    // TODO: It's also causing it to call the model twice.
    if (app.community != null && feedViewModel != null) {
      feedViewModel.loadUserStarredItemInformation();

//      feedViewModel.loadUserLikedItemInformation();
    }

    if (app.user != null) {
//      starredViewModel.loadStarredItemsForUser();
    }
    // Add more cases later as we need.
  }

  void loadUserStarredCommunityInformation() {
    communities.forEach((community) {
      if (app.user != null) {
        var starredCommunityRef = f.child('/starred_by_user/' + app.user.username.toLowerCase() + '/communities/' + community['id']);
        starredCommunityRef.onValue.listen((e) {
          community['starred'] = e.snapshot.val() != null;
        });
      } else {
        community['starred'] = false;
      }
    });
  }
}
