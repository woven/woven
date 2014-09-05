import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'dart:html';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:core_elements/core_pages.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/model/community.dart';

import 'dart:convert';
import 'package:crypto/crypto.dart';

// *
// The InboxList class is for the list of inbox items, which is pulled from Firebase.
// *
@CustomTag('community-list')
class CommunityList extends PolymerElement with Observable {
  @published App app;
  @observable List communities = toObservable([]);

  CommunityList.created() : super.created();

  var firebaseLocation = config['datastore']['firebaseLocation'];

  communitiesChanged() {
    print("Communities changed");
  }


  getCommunities() {
    // Since we call this method a second time after user
    // signed in, clear the communities list before we recreate it.
    if (communities.length > 0) { communities.clear(); }

    var firebaseRoot = new db.Firebase(firebaseLocation);
    var communityRef = firebaseRoot.child('/communities');
    // TODO: Undo the limit of 20; https://github.com/firebase/firebase-dart/issues/8
    communityRef.limit(20).onChildAdded.listen((e) {
      var community = e.snapshot.val();

      // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location",
      // so we'll add that to our local item list.
      community['id'] = e.snapshot.name();
      print(community['id']);

      // If the user is signed in, see if they've starred this community.
      if (app.user != null) {
        firebaseRoot.child('/users/' + app.user.username + '/communities/' + community['id']).onValue.listen((e) {
          if (e.snapshot.val() == null) {
            community['userStarred'] = false;
            // TODO: Add community star_count?!

          } else {
            community['userStarred'] = true;
          }
          print("${community['userStarred']}, star count: ${community['star_count']}");

          // Replace the community in the observed list w/ our updated copy.
          communities
            ..removeWhere((oldItem) => oldItem['alias'] == community['alias'])
            ..add(community)
            ..sort((m1, m2) => m1["updatedDate"].compareTo(m2["updatedDate"]));

          communities = toObservable(communities.reversed.toList());
        });
      }

      // If no updated date, use the created date.
      if (community['updatedDate'] == null) {
        community['updatedDate'] = community['createdDate'];
      }

      // Handle the case where no star count yet.
      if (community['star_count'] == null) {
        community['star_count'] = 0;
      }

      // The live-date-time element needs parsed dates.
      community['updatedDate'] = DateTime.parse(community['updatedDate']);
      community['createdDate'] = DateTime.parse(community['createdDate']);

      // Listen for realtime changes to the star count.
      communityRef.child(community['alias'] + '/star_count').onValue.listen((e) {
        int newCount = e.snapshot.val();
        community['star_count'] = newCount;
        // Replace the community in the observed list w/ our updated copy.
        // TODO: Re-writing the list each time is ridiculous!
        communities
          ..removeWhere((oldItem) => oldItem['alias'] == community['alias'])
          ..add(community)
          ..sort((m1, m2) => m1["updatedDate"].compareTo(m2["updatedDate"]));

        communities = toObservable(communities.reversed.toList());
      });



      // Insert each new community into the list.
      communities.add(community);

      // Sort the list by the item's updatedDate, then reverse it.
      communities.sort((m1, m2) => m1["updatedDate"].compareTo(m2["updatedDate"]));
      communities = toObservable(communities.reversed.toList());
    });


//    communityRef.onChildChanged.listen((e) {
//      var community = e.snapshot.val();
//
//      // If no updated date, use the created date.
//      if (community['updatedDate'] == null) {
//        community['updatedDate'] = community['createdDate'];
//      }
//
//      community['updatedDate'] = DateTime.parse(community['updatedDate']);
//
//      // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location"
//      // So we'll add that to our local community list.
//      community['id'] = e.snapshot.name();
//
//      // Insert each new community into the list.
//      communities.removeWhere((oldItem) => oldItem['id'] == e.snapshot.name());
//      communities.add(community);
//
//      // Sort the list by the item's updatedDate, then reverse it.
//      communities.sort((m1, m2) => m1["updatedDate"].compareTo(m2["updatedDate"]));
//      communities = community.reversed.toList();
//    });

  }

  // This is triggered by an app.changes.listen.
//  void getUserStarredCommunities() {
//    // Determine if this user has starred the community.
//    communities.forEach((community) {
//      var starredCommunityRef = new db.Firebase(firebaseLocation + '/users/' + app.user.username + '/communities/' + community['id']);
//      starredCommunityRef.onValue.listen((e) {
//        if (e.snapshot.val() == null) {
//          community['userStarred'] = false;
//        } else {
//          community['userStarred'] = true;
//        }
//
//      // Replace the community in the observed list w/ our updated copy.
//      communities
//        ..removeWhere((oldItem) => oldItem['alias'] == community['alias'])
//        ..add(community)
//        ..sort((m1, m2) => m1["updatedDate"].compareTo(m2["updatedDate"]));
//
//      communities = toObservable(communities.reversed.toList());
//
//      });
//    });
//  }

  void selectCommunity(Event e, var detail, Element target) {
    // Look in the communities list for the item that matches the
    // id passed in the data-id attribute on the element.
    var communityMap = communities.firstWhere((i) => i['id'] == target.dataset['id']);

    var community = new CommunityModel()
      ..alias = communityMap['alias']
      ..name = communityMap['name']
      ..createdDate = communityMap['createdDate']
      ..updatedDate = communityMap['updatedDate'];

    // TODO: app.selectCommunity() method, or just instantiate the community object here.
    app.selectedPage = 0;
    app.community = community;
//    app.resetCommunityTitle();

    app.router.dispatch(url: "/" + app.community.alias);
  }

  toggleLike(Event e, var detail, Element target) {
    // Don't fire the core-item's on-click, just the icon's.
    e.stopPropagation();

    if (target.attributes["icon"] == "favorite") {
      target.attributes["icon"] = "favorite-outline";
    } else {
      target.attributes["icon"] = "favorite";
    }

    target
      ..classes.toggle("selected");
  }

  void handleCallToAction() {
    // Reset the current selectedItem so item-preview grabs it from the URL
    app.selectedItem == null;
    app.router.dispatch(url: "item/LUpWdzZXaWd4dHdvRWM1ZGNhdXo=");
  }

  toggleStar(Event e, var detail, Element target) {
    // Don't fire the core-item's on-click, just the icon's.
    e.stopPropagation();

    if (app.user == null) {
      app.showMessage("Kindly sign in first.", "important");
      return;
    }

    bool isStarred = (target.classes.contains("selected"));
    var community = communities.firstWhere((i) => i['id'] == target.dataset['id']);

    var firebaseRoot = new db.Firebase(firebaseLocation);
    var starredCommunityRef = firebaseRoot.child('/users/' + app.user.username + '/communities/' + community['id']);
    var communityRef = firebaseRoot.child('/communities/' + community['id']);

    if (isStarred) {
      // If it's starred, time to unstar it.
      community['userStarred'] = false;
      starredCommunityRef.remove();

      // Update the star count.
      communityRef.child('/star_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          community['star_count'] = 0;
          return 0;
        } else {
          community['star_count'] = currentCount - 1;
          return currentCount - 1;
        }
      });

      // Update the list of users who starred.
      communityRef.child('/star_users/' + app.user.username).remove();

    } else {
      // If it's not starred, time to star it.
      community['userStarred'] = true;
      starredCommunityRef.set(true);

      // Update the star count.
      communityRef.child('/star_count').transaction((currentCount) {
        if (currentCount == null || currentCount == 0) {
          community['star_count'] = 1;
          return 1;
        } else {
          community['star_count'] = currentCount + 1;
          return currentCount + 1;
        }
      });

      // Update the list of users who starred.
      communityRef.child('/star_users/' + app.user.username).set(true);

    }

    // Replace the community in the observed list w/ our updated copy.
    communities.removeWhere((oldItem) => oldItem['alias'] == community['alias']);
    communities.add(community);
    communities.sort((m1, m2) => m1["updatedDate"].compareTo(m2["updatedDate"]));
    communities = toObservable(communities.reversed.toList());

    print(communities);
  }

  formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  attached() {
    app.pageTitle = "Communities";
    getCommunities();

    app.changes.listen((List<ChangeRecord> records) {
      if (app.user != null) {
        getCommunities();
      }
    });
  }

  detached() {
    //
  }
}
