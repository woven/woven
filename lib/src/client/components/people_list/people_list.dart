import 'dart:html';
import 'dart:async';
import 'package:polymer/polymer.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/client/view_model/people.dart';
import 'package:woven/src/client/infinite_scroll.dart';
import 'package:core_elements/core_header_panel.dart';

/**
 * This class represents a list of users.
 */
@CustomTag('people-list')
class PeopleList extends PolymerElement with Observable {
  @published App app;
  @published PeopleViewModel viewModel;

  List<StreamSubscription> subscriptions = [];

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
    var scroller = app.scroller;
    HtmlElement element = $['content-container'];
    var scroll = new InfiniteScroll(pageSize: 10, element: element, scroller: scroller, threshold: 0);

    subscriptions = [];
    subscriptions.add(scroll.onScroll.listen((_) {
      if (!viewModel.reloadingContent) viewModel.paginate();
    }));
  }

  attached() {
    print('+people');
    app.pageTitle = "People";

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

  detached() => subscriptions.forEach((subscription) => subscription.cancel());
}
