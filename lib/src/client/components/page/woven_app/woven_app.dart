import 'dart:html';
import 'dart:async';
import 'dart:js' show JsObject;
import 'dart:mirrors';
import 'dart:convert';

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
    app.router.dispatch(url: target.dataset['url']);
  }

  void scrollToTop() {
    app.scroller.scrollTop = 0;
  }

  void goBack(Event e, var detail, Element target) {
    if (app.previousPage == 0) app.router.dispatch(url: (app.community != null ? '/${app.community.alias}' : '/'));
    if (app.previousPage == 5) app.router.dispatch(url: (app.community != null ? '/${app.community.alias}/events' : '/events'));
    (app.community != null) ? app.selectedPage = app.previousPage : app.selectedPage = 4;
  }

  signInWithFacebook() {
    app.signInWithFacebook();
  }

  void signOut() {
    app.user = null;
    app.mainViewModel.invalidateUserState();
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

    app.showMessage("$greeting, ${app.user.firstName}.");
  }

  // Toggle the drawer panel.
  togglePanel() {
    CoreDrawerPanel panel = this.shadowRoot.querySelector('core-drawer-panel');
    panel.togglePanel();
  }

  // Toggle the Add Stuff dialog.
  toggleAddStuff() {
    if (app.user == null) {
      app.showMessage("Kindly sign in first.", "important");
      return;
    }
    AddStuff e = this.shadowRoot.querySelector('add-stuff');
    e.toggleOverlay();
  }

// Toggle the sign in dialog.
  toggleSignIn() {
    app.showMessage("Kindly sign in first.", "important");
//    SignInDialog e = this.shadowRoot.querySelector('sign-in');
//    e.toggle();
//    CoreOverlay e = this.shadowRoot.querySelector('#sign-in-overlay');
//    e.toggle();
  }

  attached() {
    // Whenever we load the app, try to see what's the current user (i.e. have we signed in?).
    HttpRequest.getString(Routes.currentUser.reverse([])).then((String contents) {
      var response = Response.fromJson(JSON.decode(contents));
      if (response.success && response.data != null) {
        app.user = UserModel.fromJson(response.data);

        //TODO: Aha! This triggers a feedViewModel load.
        app.mainViewModel.invalidateUserState();

        // On sign in, greet the user.
        if (app.user.isNew != true) greetUser();
      }

      app.hasTriedLoadingUser = true;
      if (app.user == null && window.location.pathname == '/') app.showHomePage = true;
    });

    // Listen for App changes so we can do some things.
    app.changes.listen((List<ChangeRecord> records) {
      PropertyChangeRecord record = records[0] as PropertyChangeRecord;
      String changedValue = MirrorSystem.getName(record.name);

//      print("$changedValue changed from ${record.oldValue} (${record.oldValue.runtimeType}) to ${record.newValue} (${record.newValue.runtimeType})");

      // If page title changes, show it awesomely.
      HtmlElement el;
      el = this.shadowRoot.querySelector('#page-title');
      if (el != null) {
        el.style.opacity = '0';
        new Timer(new Duration(milliseconds: 750), () {
          el.style.opacity = '1';
          el.text = (app.pageTitle != null) ? '${app.pageTitle}' : '';
        });
      }

//      if (changedValue == "community") {
//        HtmlElement sidebarTitleElement;
//        sidebarTitleElement = this.shadowRoot.querySelector('#sidebar-title');
//        if (app.community != null) {
//          // Fade in the community title.
////           sidebarTitleElement.style.opacity = '0';
//           new Timer(new Duration(milliseconds: 750), () {
//             sidebarTitleElement.style.opacity = '1';
//           });
//         }
//      }

      // If brand new user, greet them.
      if (app.user != null && app.user.isNew == true) {
        greetUser();
        app.user.isNew = false;
      }
    });

    // A temporary place for some scripts I'm running.
    //
  }
}
