import 'package:polymer/polymer.dart';
import 'package:core_elements/core_drawer_panel.dart';
import 'package:woven/src/app.dart';
import 'dart:html';

@CustomTag('woven-app')
class WovenApp extends PolymerElement with Observable {
  @published App app = new App();

  CoreDrawerPanel get drawer => $['drawer-panel'];

  void switchPage(Event e, var detail, Element target) {
    app.selectedPage = target.dataset['page'];
  }

  WovenApp.created() : super.created();

  attached() => print("+WovenApp");
  detached() => print("-WovenApp");
}
