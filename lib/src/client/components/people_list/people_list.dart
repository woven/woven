import 'package:polymer/polymer.dart';
import 'package:firebase/firebase.dart' as db;
import 'dart:html';
import 'dart:async';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/client/view_model/main.dart';
import 'package:core_elements/core_pages.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/components/page/woven_app/woven_app.dart' show showToastMessage;
import 'package:woven/src/client/infinite_scroll.dart';
import 'package:core_elements/core_header_panel.dart';

import 'dart:convert';
import 'package:crypto/crypto.dart';

/**
 * This class represents a list of users.
 */
@CustomTag('people-list')
class PeopleList extends PolymerElement with Observable {
  @published App app;
  @published MainViewModel viewModel;

  List<StreamSubscription> subscriptions;

  PeopleList.created() : super.created();

  InputElement get subject => $['subject'];

  void selectUser(Event e, var detail, Element target) {
    var selectedUser = target.dataset['user'];
    app.showMessage("More about $selectedUser coming soon!", "important");
    // TODO: User profiles, routes, etc.
  }

  formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  /**
   * Initializes the infinite scrolling ability.
   */
  initializeInfiniteScrolling() {
    CoreHeaderPanel el = document.querySelector("woven-app").shadowRoot.querySelector("#main-panel");
    HtmlElement scroller = el.scroller;
    HtmlElement element = $['content-container'];
    var scroll = new InfiniteScroll(pageSize: 10, element: element, scroller: scroller, threshold: 0);

    subscriptions = [];
    subscriptions.add(scroll.onScroll.listen((_) {
      if (!viewModel.reloadingContent) viewModel.paginateUsers();
    }));
  }

  attached() {
    app.pageTitle = "People";

    initializeInfiniteScrolling();
  }

  detached() {
  }
}
