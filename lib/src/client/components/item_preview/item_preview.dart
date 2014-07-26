import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:firebase/firebase.dart' as db;

@CustomTag('item-preview')
class ItemPreview extends PolymerElement {
  @published App app;

  //Unused, this is for simple gets
  get formattedDate {
    if (app.selectedItem == null) return '';
    return InputFormatter.formatMomentDate(app.selectedItem['createdDate'], short: true, momentsAgo: true);
  }

  String formatItemDate(DateTime value) {
    return InputFormatter.formatMomentDate(value, short: true, momentsAgo: true);
  }

  attached() {
    print("+ItemPreview");
    app.changeTitle(app.selectedItem['subject']);
  }

  detached() {
    print("-ItemPreview");
//    app.pageTitle = "";
    app.changeTitle("");
  }

  ItemPreview.created() : super.created();
}
