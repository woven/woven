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

  Map get item => viewModel.itemViewModel.item;

  ItemView.created() : super.created() {
    new PathObserver(viewModel, [#itemViewModel, #item])
    .open((oldValue, newValue) => notifyPropertyChange(#item2, oldValue, newValue));
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
  }

  detached() {
    //
  }
}