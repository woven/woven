import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/client/view_model/chat.dart';
import 'package:woven/src/client/app.dart';

@CustomTag('chat-view')
class ChatView extends PolymerElement {
  @published App app;
  @published ChatViewModel viewModel;

  ChatView.created() : super.created();

  /**
   * Get the main scrolling element on app.
   */
  HtmlElement get scroller {
    HtmlElement el = $['scroller'];
    return el;
  }

  scrollToBottom() {
    if (viewModel.isScrollPosAtBottom || viewModel.lastScrollPos == 0) {
      Timer.run(() {
        this.scroller.scrollTop = this.scroller.scrollHeight;
        viewModel.lastScrollPos = 0; // Zero out scroll position?
      });
    }
  }

}
