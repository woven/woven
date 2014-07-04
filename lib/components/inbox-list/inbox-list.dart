//library binding_data.inbox_list;

import 'package:polymer/polymer.dart';

@CustomTag('inbox-list')
class InboxList extends PolymerElement with Observable {
  @observable List items = toObservable([]);

  InboxList.created() : super.created();
}