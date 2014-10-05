import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/config/config.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:woven/src/client/view_model/main.dart';
import 'package:woven/src/client/uri_policy.dart';

@CustomTag('item-view')
class ItemView extends PolymerElement {
  @published App app;
  @published MainViewModel viewModel;

  NodeValidator get nodeValidator => new NodeValidatorBuilder()
    ..allowHtml5(uriPolicy: new ItemUrlPolicy());

  // TODO: Revisit all this. It seems ridiculous.
  // See http://stackoverflow.com/a/25772893/1286442.
  @ComputedProperty('viewModel.itemViewModel.item')
  @observable Map get item {
    if (viewModel == null || viewModel.itemViewModel == null) return null;
    return viewModel.itemViewModel.item;
  }

  formatText(String text) {
    if (text.trim().isEmpty) return 'Loading...';
    String formattedText = InputFormatter.nl2br(InputFormatter.linkify(text.trim()));
    return formattedText;
  }

  itemChanged() {
    // Pass the item body to the safe-html element.
    HtmlElement body = $['body'];
    HtmlElement safeHtml = body.childNodes[0];
    safeHtml.shadowRoot.innerHtml = formatText(item['body']);
  }

  ItemView.created() : super.created() {
    // The old magic to ensure we're notified of changes to
    // the item in the itemViewModel. See http://stackoverflow.com/a/25772893/1286442.
//    new PathObserver(this, [#viewModel, #itemViewModel, #item])
//    .open((newValue, oldValue) {
//      notifyPropertyChange(#item, oldValue, newValue);
//
      // Trick to respect line breaks.
//      HtmlElement body = $['body'];
//      body.innerHtml = formattedBody;
//    });
  }

  String formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  toggleLike(Event e, var detail, Element target) {
    e.stopPropagation();

    viewModel.itemViewModel.toggleLike();
  }

  toggleStar(Event e, var detail, Element target) {
    e.stopPropagation();

    viewModel.itemViewModel.toggleStar();
  }

  attached() {
    print("+Item");
    app.pageTitle = "";
    if (item != null) {
      itemChanged();
    }
  }

  detached() {
    //
  }
}