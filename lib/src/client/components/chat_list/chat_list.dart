import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/shared/input_formatter.dart';

import 'package:woven/src/client/uri_policy.dart';
import 'package:woven/src/client/components/chat_view/chat_view.dart';
import 'package:woven/src/client/view_model/chat.dart';
import 'package:woven/src/client/app.dart';

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

  attached() {
//    initializeInfiniteScrolling();

    // Once the view is loaded, handle scroll position.
    viewModel.onLoad.then((_) {
      // Wait one event loop, so the view is truly loaded, then jump to last known position.
      Timer.run(() {
        chatView.scroller.scrollTop = viewModel.lastScrollPos;
      });

      // On scroll, record new scroll position.
      subscriptions.add(chatView.scroller.onScroll.listen((e) {
        viewModel.lastScrollPos = chatView.scroller.scrollTop;
      }));
    });
  }

  detached() {
    //
  }

  ChatList.created() : super.created();
}
