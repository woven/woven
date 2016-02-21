@HtmlImport('chat_view.html')

library client.components.chat_view;

import 'dart:html';

import 'package:polymer/polymer.dart';

import 'package:woven/src/client/view_model/chat.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/client/components/chat_list/chat_list.dart';
import 'package:woven/src/client/components/chat_box/chat_box.dart';

@CustomTag('chat-view')
class ChatView extends PolymerElement {
  @published App app;
  @published ChatViewModel viewModel;

  ChatView.created() : super.created();

  /// Get the main scrolling element on app.
  HtmlElement get scroller => $['scroller'];

  scrollToBottom() => this.scroller.scrollTop = this.scroller.scrollHeight;
}
