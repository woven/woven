import 'package:polymer/polymer.dart';
import 'package:woven/src/client/app.dart';
import 'dart:html';


@CustomTag('chat-view')
class ChatView extends PolymerElement {
  @published App app;

  ChatView.created() : super.created();

  /**
   * Get the main scrolling element on app.
   */
  HtmlElement get scroller {
    HtmlElement el = $['scroller'];
    return el;
  }
}
