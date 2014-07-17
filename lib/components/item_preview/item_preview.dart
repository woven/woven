import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import '../../src/app.dart';
import '../../src/input_formatter.dart';

@CustomTag('item-preview')
class ItemPreview extends PolymerElement {
  ItemPreview.created() : super.created();

  @published App app;

  get formattedDate {
    if (app.selectedItem == null) return '';
    return InputFormatter.formatMomentDate(app.selectedItem['createdDate'], short: true, momentsAgo: true);
  }
}
