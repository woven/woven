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

  NodeValidator get nodeValidator => new NodeValidatorBuilder()
  ..allowHtml5(uriPolicy: new ItemUrlPolicy());

  String formatItemDate(DateTime value) => InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  Element get elRoot => document.querySelector('woven-app').shadowRoot.querySelector('chat-list');
  ChatView get chatView => document.querySelector('woven-app').shadowRoot.querySelector('chat-view');

  /**
   * Handle formatting of the comment text.
   *
   * Format line breaks, links, @mentions.
   */
  formatText(String text) {
    if (text.trim().isEmpty) return 'Loading...';
    String formattedText = InputFormatter.formatMentions(InputFormatter.nl2br(InputFormatter.linkify(text.trim())));
    return formattedText;
  }

  /**
   * Initializes the infinite scrolling ability.
   */
  initializeInfiniteScrolling() {
    var scroller = chatView.scroller;
    HtmlElement element = $['activity-wrapper'];
    print(element);
    var scroll = new InfiniteScroll(pageSize: 10, element: element, scroller: scroller, reversed: true, threshold: 0);

    subscriptions.add(scroll.onScroll.listen((_) {
      print("Scrolling... reloading: ${viewModel.reloadingContent} // end: ${viewModel.reachedEnd}");
      if (!viewModel.reloadingContent && !viewModel.reachedEnd) viewModel.paginate();
    }));
  }

  attached() {
    initializeInfiniteScrolling();

    // Once the view is loaded, handle scroll position.
    viewModel.onLoad.then((_) {
      // Wait one event loop, so the view is truly loaded, then jump to last known position.
//      Timer.run(() => chatView.scroller.scrollTop = viewModel.lastScrollPos);
      // On scroll...
      subscriptions.add(chatView.scroller.onScroll.listen((e) {
        // ...record new scroll position.
        viewModel.lastScrollPos = chatView.scroller.scrollTop;
        // ...keep track of if we're scrolled to the bottom.
        viewModel.isScrollPosAtBottom = chatView.scroller.scrollHeight - chatView.scroller.scrollTop <= chatView.scroller.clientHeight;
      }));
    });
  }

  detached() {
    //
  }

  ChatList.created() : super.created();
}
