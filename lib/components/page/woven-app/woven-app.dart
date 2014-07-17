import 'package:polymer/polymer.dart';
import 'package:core_elements/core_drawer_panel.dart';
import 'package:woven/src/app.dart';
import 'dart:html';

@CustomTag('woven-app')
class WovenApp extends PolymerElement with Observable {
  @published App app;

  CoreDrawerPanel get drawer => $['drawer-panel'];

  toggleDrawer() {



  }




  WovenApp.created() : super.created();

  attached() => print("+WovenApp");
  detached() => print("-WovenApp");

}

