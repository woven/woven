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

  getCommunities() {
    var f = new db.Firebase(firebaseLocation + '/communities');

    // TODO: Undo the limit of 20; https://github.com/firebase/firebase-dart/issues/8
    var communityRef = f.limit(20);
    communityRef.onChildAdded.listen((e) {
      var community = e.snapshot.val();
      print(community.runtimeType);

//      print(community['name'] + community['createdDate']);
      // If no updated date, use the created date.
      if (community['updatedDate'] == null) {
        community['updatedDate'] = DateTime.parse(community['createdDate']);
      }

      // The live-date-time element needs parsed dates.
//      community['updatedDate'] = DateTime.parse(community['updatedDate']);
//      community['createdDate'] = DateTime.parse(community['createdDate']);

      // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location"
      // So we'll add that to our local item list.
      community['id'] = e.snapshot.name();

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
  void getUserStarredCommunities() {
    // Determine if this user has starred the community.
    communities.forEach((community) {
      var starredCommunityRef = new db.Firebase(firebaseLocation + '/users/' + app.user.username + '/communities/' + community['id']);
      starredCommunityRef.onValue.listen((e) {
        if (e.snapshot.val() == null) {
          community['userStarred'] = false;
        } else {
          community['userStarred'] = true;
        }
      });
    });
  }

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
    var communityMap = communities.firstWhere((i) => i['id'] == target.dataset['id']);
    print(isStarred);

    if (isStarred) {
      // If it's starred, time to unstar it.
      print("Unstar");
      communityMap['userStarred'] = false;
//      target.classes.remove("selected");
//      communities.firstWhere((i) => )
    } else {
      print("Starring");
      // If it's not starred, time to star it.
//      target.classes.add("selected");
      communityMap['userStarred'] = true;
    }
    print(communities);

    var starredCommunityRef = new db.Firebase(firebaseLocation + '/users/' + app.user.username + '/communities/' + communityMap['id']);
    starredCommunityRef.set(communityMap['userStarred']);
  }

  formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  attached() {
    print("+CommunityList");
    app.pageTitle = "Communities";
    getCommunities();

    app.changes.listen((List<ChangeRecord> records) {
      if (app.user != null) {
        getUserStarredCommunities();
      }
    });
  }

  detached() {
    print("-CommunityList");
  }
}
