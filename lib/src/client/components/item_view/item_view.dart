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

@CustomTag('item-view')
class ItemView extends PolymerElement {
  @published App app;
  @published MainViewModel viewModel;

  @ComputedProperty('viewModel.itemViewModel.item')
//  @observable Map get item => toObservable(viewModel.itemViewModel.item);
  @observable Map get item {
    if (viewModel == null) return null;
    return viewModel.itemViewModel.item;
  }

  get formattedBody {
    if (item.isEmpty) return 'Loading...';
    return "${InputFormatter.nl2br(item['body'])}";
  }

  itemChanged() {
    // Trick to respect line breaks.
    HtmlElement body = $['body'];
    body.innerHtml = formattedBody;
  }


  ItemView.created() : super.created() {
    // Some magic to ensure we're notified of changes to
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
      // Trick to respect line breaks.
      HtmlElement body = $['body'];
      body.innerHtml = formattedBody;
    }
  }

  detached() {
    //
  }
}