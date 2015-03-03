import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'dart:html';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:core_elements/core_pages.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/model/community.dart';
import 'package:woven/src/client/view_model/main.dart';
import 'dart:math';
import 'dart:async' show Timer;

import 'dart:convert';
import 'package:crypto/crypto.dart';

// *
// The InboxList class is for the list of inbox items, which is pulled from Firebase.
// *
@CustomTag('community-list')
class CommunityList extends PolymerElement with Observable {
  @published App app;
  @published MainViewModel viewModel;

  CommunityList.created() : super.created();

  void selectCommunity(Event e, var detail, Element target) {
    // Look in the communities list for the item that matches the
    // id passed in the data-id attribute on the element.
    var communityMap = viewModel.communities.firstWhere((i) => i['id'] == target.dataset['id']);

    // Dave: you should construct these CommunityModel's way sooner. In fact, all data should be modeled,
    // right after the data has been loaded from the DB. Consider making some generic functions for these.
    // Maybe `new CommunityModel.fromData(communityMap)` ?
    var community = new CommunityModel()
      ..alias = communityMap['alias']
      ..name = communityMap['name']
      ..createdDate = communityMap['createdDate']
      ..updatedDate = communityMap['updatedDate'];

    app.community = community;
    app.selectedPage = 'lobby';

    app.router.dispatch(url: "/" + app.community.alias);
  }

  void toggleStar(Event e, var detail, Element target) {
    // Don't fire the core-item's on-click, just the icon's.
    e.stopPropagation();

    viewModel.toggleCommunityStar(target.dataset['id']);
  }

  formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  attached() {
    if (config['debug_mode']) print('+channels');
    if (config['debug_mode'] == true) print("+CommunityList");
    app.pageTitle = "Channels";
  }

  detached() {
    if (config['debug_mode']) print('-channels');
  }
}
