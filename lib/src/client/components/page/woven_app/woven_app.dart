library woven_app;

import 'package:polymer/polymer.dart';

import 'package:woven/src/client/app.dart';

@CustomTag('woven-app')
class WovenApp extends PolymerElement with Observable {
  @observable App app = new App();

  WovenApp.created() : super.created();

  attached() {
    print('+woven-app');
    print(app.cache);
  }
}
