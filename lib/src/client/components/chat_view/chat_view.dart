import 'package:polymer/polymer.dart';
import 'package:woven/src/client/app.dart';


@CustomTag('chat-view')
class ChatView extends PolymerElement {
  @published App app;

  ChatView.created() : super.created();
}
