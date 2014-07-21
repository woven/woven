import 'package:polymer/polymer.dart';
import 'package:core_elements/core_drawer_panel.dart';
import 'package:woven/src/app.dart';
import 'dart:html';
import 'package:core_elements/core_animated_pages.dart';

@CustomTag('woven-app')
class WovenApp extends PolymerElement with Observable {
  @published App app = new App();

  CoreDrawerPanel get drawer => $['drawer-panel'];
  //CoreAnimatedPages get pages => $['drawer-panel'];

  void switchPage(Event e, var detail, Element target) {
    app.selectedPage = int.parse(target.dataset['page']);
  }

  WovenApp.created() : super.created();

  attached() => print("+WovenApp");
  detached() => print("-WovenApp");
}
