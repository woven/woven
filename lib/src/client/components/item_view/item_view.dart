library components.item_view.dart;

import 'dart:html';
import 'dart:async';

import 'package:polymer/polymer.dart';

import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/src/client/view_model/item.dart';
import 'package:woven/src/client/uri_policy.dart';

@CustomTag('item-view')
class ItemView extends PolymerElement with Observable {
  @published App app;
  @published ItemViewModel viewModel;

  List<StreamSubscription> subscriptions = [];

  NodeValidator get nodeValidator => new NodeValidatorBuilder()
    ..allowHtml5(uriPolicy: new ItemUrlPolicy());

  // TODO: Revisit all this. It seems ridiculous. See http://stackoverflow.com/a/25772893/1286442.
  @ComputedProperty('viewModel.item')
  Map get item {
    if (viewModel == null) return null;
    return viewModel.item;
  }

  /**
   * Handle formatting of the body text.
   *
   * Format line breaks, links, @mentions.
   */
  String get getFormattedBody {
    if (item['body'] == null || item['body'].trim().isEmpty) return 'Loading...';
    return InputFormatter.formatMentions(InputFormatter.nl2br(InputFormatter.linkify(item['body'].trim())));
  }

  formatText(String text) {
    if (text == null || text.trim().isEmpty) return 'Loading...';
    String formattedText = InputFormatter.formatMentions(InputFormatter.nl2br(InputFormatter.linkify(text.trim())));
    return formattedText;
  }

  /**
   * Format the given string with "a" or "an" or none.
   */
  formatWordArticle(String content) {
    return InputFormatter.formatWordArticle(content);
  }

  ItemView.created() : super.created();

  String formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  formatEventDate(DateTime startDate) {
    // TODO: Bring back endDate, currently null.
    return InputFormatter.formatDate(startDate.toLocal(), showHappenedPrefix: true, trimPast: true, detailed: true);
  }

  toggleLike(Event e, var detail, Element target) {
    e.stopPropagation();
    viewModel.toggleLike();
  }

  toggleStar(Event e, var detail, Element target) {
    e.stopPropagation();
    viewModel.toggleStar();
  }

  attached() {


    app.scroller.scrollTop = 0;

    // Once the view is loaded, handle scroll position.
    viewModel.onLoad.then((_) {
      // Wait one event loop, so the view is truly loaded, then jump to last known position.
      Timer.run(() {
        app.scroller.scrollTop = viewModel.lastScrollPos;
      });

      // On scroll, record new scroll position.
      subscriptions.add(app.scroller.onScroll.listen((e) {
        viewModel.lastScrollPos = app.scroller.scrollTop;
      }));
    });
  }

  detached() {
    subscriptions.forEach((subscription) => subscription.cancel());
    app.router.selectedItem = null;
  }
}