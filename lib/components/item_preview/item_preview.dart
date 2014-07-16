import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import '../../src/app.dart';

@CustomTag('item-preview')
class ItemPreview extends PolymerElement {
  ItemPreview.created() : super.created();

  @published App app;
}
