@HtmlImport('community_list.html')

library components.community_list;

import 'dart:html';
import 'dart:math';
import 'dart:async' show Timer;
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:crypto/crypto.dart';

import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:core_elements/core_pages.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/model/community.dart';
import 'package:woven/src/client/view_model/main.dart';
import 'package:woven/src/client/components/widgets/join_button/join_button.dart';

// *
// The InboxList class is for the list of inbox items, which is pulled from Firebase.
// *
@CustomTag('community-list')
class CommunityList extends PolymerElement with Observable {
  @published App app;
  @published MainViewModel viewModel;
//  @observable CommunityModel community;

  CommunityList.created() : super.created();

  void selectCommunity(Event e, var detail, Element target) {
    // Look in the communities list for the item that matches the
    // id passed in the data-id attribute on the element.
    var community = viewModel.communities.firstWhere((i) => i.id == target.dataset['id']);

    app.changeCommunity(community.alias);
    app.router.selectedPage = 'lobby';

    app.router.dispatch(url: "/" + community.alias);
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
    if (app.debugMode) print("+CommunityList");
//    app.pageTitle = "Channels";
  }

  detached() {
    if (app.debugMode) print('-CommunityList');
  }
}
