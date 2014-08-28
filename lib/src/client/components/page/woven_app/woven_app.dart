import 'dart:html';
import 'dart:async';
import 'dart:js' show JsObject;

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_drawer_panel.dart';
import 'package:core_elements/core_icon_button.dart';
import 'package:paper_elements/paper_toast.dart';

import 'package:woven/config/config.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/src/shared/model/user.dart';

import 'package:woven/src/client/components/add_stuff/add_stuff.dart';
//import 'package:woven/src/client/components/dialog/sign_in/sign_in.dart';
import 'package:core_elements/core_overlay.dart';


@CustomTag('woven-app')
class WovenApp extends PolymerElement with Observable {
  @published App app = new App();
  @observable var responsiveWidth = "600px";

  WovenApp.created() : super.created();

  void switchPage(Event e, var detail, Element target) {
    togglePanel();
    app.selectedPage = int.parse(target.dataset['page']);

    app.router.dispatch(url: target.dataset['url']);
  }

  signInWithFacebook() {
    app.signInWithFacebook();
  }

  void signOut() {
    app.user = null;
  }

  // Greet the user upon sign in.
  greetUser() {
    var greeting;
    DateTime now = new DateTime.now();

    if (now.hour < 12) {
      greeting = "Good morning";
    } else {
      if (now.hour >= 12 && now.hour <= 17) {
        greeting = "Good afternoon";
      } else if (now.hour > 17 && now.hour <= 24) {
        greeting = "Good evening";
      } else {
        greeting = "Hello";
      }
    }

    showToastMessage("$greeting, ${app.user.firstName}.");
  }

  // Show the toast message.
  showToastMessage(String message) {
    PaperToast toastMessage = $['toast-message'];
    toastMessage.text = "$message";
    toastMessage.show();
  }

  // Toggle the drawer panel.
  togglePanel() {
    CoreDrawerPanel panel = this.shadowRoot.querySelector('core-drawer-panel');
    panel.togglePanel();
  }

  // Toggle the Add Stuff dialog.
  toggleAddStuff() {
    AddStuff e = this.shadowRoot.querySelector('add-stuff');
    e.toggleOverlay();
  }

// Toggle the sign in dialog.
  toggleSignIn() {
    window.alert("Kindly sign in first.");
//    SignInDialog e = this.shadowRoot.querySelector('sign-in');
//    e.toggle();
//    CoreOverlay e = this.shadowRoot.querySelector('#sign-in-overlay');
//    e.toggle();
  }

  attached() {
    // Whenever we load the app, try to see what's the current user (i.e. have we signed in?).
    HttpRequest.getString(Routes.currentUser.reverse([])).then((String contents) {
      var response = Response.decode(contents);
      if (response.success && response.data !=null) {
        app.user = UserModel.decode(response.data);
        // On sign in, greet the user.
        if (app.user != null && app.user.isNew != true) {
          greetUser();
        }
      }
    });

    // Listen for App changes so we can do some things.
    app.changes.listen((e) {
      // If brand new user, greet them.
      if (app.user != null && app.user.isNew == true) {
        greetUser();
        app.user.isNew = false;
      }

      // If page title changes, show it awesomely.
      HtmlElement el;
      el = this.shadowRoot.querySelector('#page-title');

      if (app != null && el.text != app.pageTitle) {
        el.style.opacity = '0';
        new Timer(new Duration(milliseconds: 750), () {
          el.text = app.pageTitle;
          el.style.opacity = '1';
        });
      }
    });

  }
}