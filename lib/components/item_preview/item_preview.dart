import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import '../../src/app.dart';
import '../../src/input_formatter.dart';
import 'package:firebase/firebase.dart' as db;

@CustomTag('item-preview')
class ItemPreview extends PolymerElement {
  @published App app;

  get formattedDate {
    if (app.selectedItem == null) return '';
    return InputFormatter.formatMomentDate(app.selectedItem['createdDate'], short: true, momentsAgo: true);
  }

  attached() {
    print("+ItemPreview");
  }

  ItemPreview.created() : super.created();
}
