@HtmlImport('woven_app.html')
library woven_app;

import 'package:polymer/polymer.dart';

import 'package:woven/src/client/app.dart';
import 'package:woven/src/client/components/page/main/main.dart';

@CustomTag('woven-app')
class WovenApp extends PolymerElement with Observable {
  @observable App app = new App();

  WovenApp.created() : super.created();
}
