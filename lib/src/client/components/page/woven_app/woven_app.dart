import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_scaffold.dart';
import 'package:core_elements/core_animated_pages.dart';

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

    app.router.dispatch(url: target.dataset['url']);
  }

  signInWithFacebook(Event e, var detail, Element target) {
//    HtmlElement messageP = $['message'];
//    messageP.text = "Sign in coming soon! :)";
//    messageP.style.opacity = '1';

    var cfg = config['authentication']['facebook'];
    var appId = cfg['appId'];
    var url = cfg['url'];

    var signInUrl = 'https://www.facebook.com/dialog/oauth/?client_id=$appId&redirect_uri=$url&scope=email';
    window.location.assign(signInUrl);
  }

  void signOut() {
    app.user = null;
  }

  WovenApp.created() : super.created();

  attached() {
    // Whenever we load the app, try to see what's the current user (i.e. have we signed in?).
    HttpRequest.getString(Routes.currentUser.reverse([])).then((String contents) {
      print("CONTENTS: $contents");
      var response = Response.decode(contents);
      if (response.success && response.data !=null) {
        app.user = UserModel.decode(response.data);
      }
    });

  }
}