@HtmlImport('inbox_list.html')

library components.inbox_list;

import 'dart:html';
import 'dart:async';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_item.dart';
import 'package:core_elements/core_icon.dart';
import 'package:core_elements/core_tooltip.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:crypto/crypto.dart';

import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/client/view_model/feed.dart';
import 'package:woven/src/client/infinite_scroll.dart';
import 'package:woven/src/client/components/widgets/live_date_time/live_date_time.dart';
import 'package:woven/src/client/components/item/item.dart';
import 'package:woven/src/client/components/user_picture/user_picture.dart';
import 'package:woven/src/client/components/widgets/uri_preview/uri_preview.dart';

/**
 * A list of items.
 */
@CustomTag('inbox-list')
class InboxList extends PolymerElement with Observable {
  @published App app;
  @published FeedViewModel viewModel;

  List<StreamSubscription> subscriptions = [];

  InboxList.created() : super.created();

  InputElement get subject => $['subject'];

  db.Firebase get f => app.f;

  void selectItem(Event e, var detail, Element target) {
    // Look in the items list for the item that matches the
    // id passed in the data-id attribute on the element.
    var item = viewModel.items.firstWhere((i) => i['id'] == target.dataset['id']);

    app.router.previousPage = app.router.selectedPage;
    app.router.selectedItem = item;

    var str = target.dataset['id'];
    var bytes = UTF8.encode(str);
    var base64 = CryptoUtils.bytesToBase64(bytes);

    app.router.dispatch(url: "/item/$base64");
  }

  toggleLike(Event e, var detail, Element target) {
    e.stopPropagation();

//    if (target.classes.contains("selected")) {
//      target.classes.remove("clicked");
//    } else {
//      target.classes.add("clicked");
//    }

    viewModel.toggleItemLike(target.dataset['id']);
  }

  toggleStar(Event e, var detail, Element target) {
    e.stopPropagation();

    viewModel.toggleItemStar(target.dataset['id']);
  }

  formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  formatEventDate(DateTime startDate) {
    // TODO: Bring back endDate, currently null.
    return InputFormatter.formatDate(startDate.toLocal(), showHappenedPrefix: true, trimPast: true);
  }

  /**
   * Initializes the infinite scrolling ability.
   */
  initializeInfiniteScrolling() {
    var scroller = app.scroller;
    HtmlElement element = $['content-container'];
    var scroll = new InfiniteScroll(pageSize: 20, element: element, scroller: scroller, threshold: 0);

    subscriptions.add(scroll.onScroll.listen((_) {
//      print('scrolled2 for ' + app.router.selectedPage);
//      print('DEBUG: typeFilter: ${viewModel.typeFilter} // selectedPage: ${app.router.selectedPage}');
      if (viewModel.typeFilter != app.router.selectedPage) return;
//      print("DEBUG: ${viewModel.reloadingContent} // ${viewModel.reachedEnd}");

      if (!viewModel.reloadingContent && !viewModel.reachedEnd) viewModel.paginate();
    }));
  }

  attached() {
    if (app.debugMode) print('+InboxList');

    if (app.debugMode) print('DEBUG: ${app.scroller}');

    initializeInfiniteScrolling();

    // Once the view is loaded, handle scroll position.
    viewModel.onLoad.then((_) {
      // Wait one event loop, so the view is truly loaded, then jump to last known position.
      Timer.run(() {
        app.scroller.scrollTop = viewModel.lastScrollPos;
      });

      // On scroll, record new scroll position.
      subscriptions.add(app.scroller.onScroll.listen((e) {
        viewModel.lastScrollPos = app.scroller.scrollTop;
      }));
    });
  }

  detached() {
    if (app.debugMode) print('-InboxList');
//    viewModel.lastScrollPos = app.scroller.scrollTop;

    subscriptions.forEach((subscription) => subscription.cancel());
  }
}
