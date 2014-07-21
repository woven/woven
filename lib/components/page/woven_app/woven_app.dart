import 'package:polymer/polymer.dart';
import 'package:core_elements/core_scaffold.dart';
import 'package:woven/src/app.dart';
import 'dart:html';
import 'package:paper_elements/core_animated_pages.dart';

@CustomTag('woven-app')
class WovenApp extends PolymerElement with Observable {
  @published App app = new App();

  CoreScaffold get scaffold => $['scaffold'];

  void switchPage(Event e, var detail, Element target) {
    app.selectedPage = int.parse(target.dataset['page']);
    scaffold.closeDrawer();
  }

  WovenApp.created() : super.created();

  attached() => print("+WovenApp");
  detached() => print("-WovenApp");
}
