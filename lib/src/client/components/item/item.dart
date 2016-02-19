import 'dart:html';
import 'dart:async';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:crypto/crypto.dart';
import 'package:core_elements/core_tooltip.dart';

import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/client/view_model/feed.dart';
import 'package:woven/src/client/model/message.dart';

/**
 * A list of items.
 */
@CustomTag('x-item')
class Item extends PolymerElement with Observable {
  @published Map item;
  @published App app;
  @published FeedViewModel viewModel;

  List<StreamSubscription> subscriptions = [];

  Item.created() : super.created();

  InputElement get subject => $['subject'];

  void selectItem(Event e, var detail, Element target) {
    // Look in the items list for the item that matches the
    // id passed in the data-id attribute on the element.
    var item =
        viewModel.items.firstWhere((i) => i['id'] == target.dataset['id']);

    app.router.previousPage = app.router.selectedPage;
    app.router.selectedItem = item;
    app.router.selectedPage = 'item';

    var str = target.dataset['id'];
    var bytes = UTF8.encode(str);
    var base64 = CryptoUtils.bytesToBase64(bytes);

    app.router.dispatch(url: "/item/$base64");
  }

  toggleLike(Event e, var detail, Element target) {
    e.stopPropagation();

//    if (target.classes.contains("selected")) {
//      target.classes.remove("clicked");
//    } else {
//      target.classes.add("clicked");
//    }

    viewModel.toggleItemLike(target.dataset['id']);
  }

  shareToChannel(Event e, var detail, Element target) {
    e.stopPropagation();

    var itemId = target.dataset['id'];

    var now = new DateTime.now().toUtc();
    var priority = now.millisecondsSinceEpoch;

    // Notify lobby about new item.
    var message = new Message()
      ..type = 'item'
      ..priority = priority
      ..data = {'event': 'added', 'type': 'news', 'id': '$itemId'}
      ..community = app.community.alias
      ..usernameForDisplay = app.user.username
      ..user = app.user.username.toLowerCase();

    Message.add(message, app.f);

    if (app.community != null) {
      app.router.selectedPage = 'lobby';
      app.router.dispatch(url: '/${app.community.alias}');
    }
  }

  void toggleStar(Event e, var detail, Element target) {
    e.stopPropagation();

    viewModel.toggleItemStar(target.dataset['id']);
  }

  void deleteItem(Event e, var detail, Element target) {
    e.stopPropagation();

    viewModel.deleteItem(target.dataset['id']);

    new Timer(new Duration(milliseconds: 500), () {
      this.style.display = 'none';
      new Timer(new Duration(milliseconds: 500), () {
        app.showMessage('Poof. All gone, ${app.user.firstName}.');
      });
    });
  }

  /**
   * Format the given string with "a" or "an" or none.
   */
  formatWordArticle(String content) {
    return InputFormatter.formatWordArticle(content);
  }

  formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, momentsAgo: true);
  }

  formatEventDate(DateTime startDate) {
    // TODO: Bring back endDate, currently null.
    return InputFormatter.formatDate(startDate.toLocal(),
        showHappenedPrefix: true, trimPast: true);
  }

  stopProp(Event e) {
    e.stopPropagation();
  }

  attached() {
    //
  }

  detached() {
    //
  }
}
