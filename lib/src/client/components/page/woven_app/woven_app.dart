import 'package:polymer/polymer.dart';
import 'package:core_elements/core_scaffold.dart';
import 'package:woven/src/client/app.dart';
import 'dart:html';
import 'package:paper_elements/core_animated_pages.dart';
import 'package:woven/config/config.dart';

get fbConfig => config['authentication']['facebook'];
get appId => fbConfig['appId'];
get url => fbConfig['url'];

@CustomTag('woven-app')
class WovenApp extends PolymerElement with Observable {
  @published App app = new App();

  var loginLinkUrl = 'https://www.facebook.com/dialog/oauth/?client_id=$appId&redirect_uri=$url&state=TEST_TOKEN&scope=email';

  CoreScaffold get scaffold => $['scaffold'];

  void switchPage(Event e, var detail, Element target) {
    app.selectedPage = int.parse(target.dataset['page']);
    scaffold.closeDrawer();
  }

  WovenApp.created() : super.created();

  attached() => print("+WovenApp");
  detached() => print("-WovenApp");
}




