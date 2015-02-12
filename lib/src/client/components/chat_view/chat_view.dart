import 'package:polymer/polymer.dart';
import 'dart:html';
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
}
