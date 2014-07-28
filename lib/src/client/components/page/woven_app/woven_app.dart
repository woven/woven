import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_scaffold.dart';
import 'package:paper_elements/core_animated_pages.dart';

import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/src/shared/model/user.dart';

@CustomTag('woven-app')
class WovenApp extends PolymerElement with Observable {
  @published App app = new App();

  void switchPage(Event e, var detail, Element target) {
    CoreScaffold scaffold = $['scaffold'];
    app.selectedPage = int.parse(target.dataset['page']);
    scaffold.closeDrawer();
  }

  void signInWithFacebook(Event e, var detail, Element target) {
    var cfg = config['authentication']['facebook'];
    var appId = cfg['appId'];
    var url = cfg['url'];

    var signInUrl = 'https://www.facebook.com/dialog/oauth/?client_id=$appId&redirect_uri=$url&state=TEST_TOKEN&scope=email';
    window.location.assign(signInUrl);
  }

  void signOut() {
    app.user = null;
  }

  WovenApp.created() : super.created();

  attached() {
    print("+WovenApp");

    // Whenever we load the app, try to see what's the current user (i.e. have we signed in?).


    HttpRequest.getString(Routes.currentUser.reverse([])).then((String contents) {
      var response = Response.decode(contents);
      if (response.success) {
        app.user = UserModel.decode(response.data);
      }
    });
  }

  detached() => print("-WovenApp");
}




