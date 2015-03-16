import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/shared/input_formatter.dart';

import 'package:woven/src/client/uri_policy.dart';
import 'package:woven/src/client/components/chat_view/chat_view.dart';
import 'package:woven/src/client/view_model/chat.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/client/infinite_scroll.dart';

@CustomTag('chat-list')
class ChatList extends PolymerElement {
  @published ChatViewModel viewModel;
  @published App app;
  List<StreamSubscription> subscriptions = [];

  String formatItemDate(DateTime value) => InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);

  ChatView get chatView => document.querySelector('woven-app').shadowRoot.querySelector('chat-view');
  Element get chatList => chatView.shadowRoot.querySelector('chat-list');

  /**
   * Handle formatting of the comment text.
   *
   * Format line breaks, links, @mentions.
   */
  formatText(String text) {
    if (text == null) return '';
    String formattedText = InputFormatter.formatMentions(InputFormatter.nl2br(text.trim()));

    return formattedText;
  }

  /**
   * Initializes the infinite scrolling ability.
   */
  initializeInfiniteScrolling() {
    var scroller = chatView.scroller;
    HtmlElement element = $['activity-wrapper'];
    var scroll = new InfiniteScroll(pageSize: 10, element: element, scroller: scroller, reversed: true, threshold: 0);

    subscriptions.add(scroll.onScroll.listen((_) {
      if (!viewModel.reloadingContent && !viewModel.reachedEnd) viewModel.paginate();
    }));
  }

  loadNextPage() {
    HtmlElement element = $['activity-wrapper'];
    HtmlElement scroller = chatView.scroller;
    var prevHeight = element.clientHeight;

    viewModel.loadMessagesByPage().then((_) {
      var oldPos = scroller.scrollTop;
      Timer.run(() {
        scroller.scrollTop = element.clientHeight - prevHeight + oldPos;
      });
    });
  }

  dismissHighlightedMessages() {
    var indexOfLastItemSeen = viewModel.indexOfClosestItemByDate(app.timeOfLastFocus);
    if (indexOfLastItemSeen == null) return; // No messages since last focus.
    var lastItemSeen = viewModel.messages.elementAt(indexOfLastItemSeen);

    int count = 0;
    viewModel.messages.sublist(indexOfLastItemSeen).reversed.forEach((message) {
      count++;
      new Timer(new Duration(milliseconds: count*700), () {
        message['highlighted'] = false;
      });
    });
  }


  attached() {
    if (app.debugMode) print('+ChatList');
    // TODO: Bring back infinite scrolling on chat.
//    initializeInfiniteScrolling();

    // Once the view is loaded, handle scroll position.
    viewModel.onLoad.then((_) {
      // Wait one event loop, so the view is truly loaded, then jump to last known position.
      Timer.run(() => chatView.scroller.scrollTop = viewModel.lastScrollPos);
      // On scroll...
      subscriptions.add(chatView.scroller.onScroll.listen((e) {
        // ...record new scroll position.
        viewModel.lastScrollPos = chatView.scroller.scrollTop;
        // ...keep track of if we're scrolled to the bottom.
        viewModel.isScrollPosAtBottom = chatView.scroller.scrollHeight - chatView.scroller.scrollTop <= chatView.scroller.clientHeight;
      }));

      window.onFocus.listen((_) => dismissHighlightedMessages());
    });
  }

  detached() {
    subscriptions.forEach((subscription) => subscription.cancel());
    if (app.debugMode) print('-ChatList');
  }

  ChatList.created() : super.created();
}
