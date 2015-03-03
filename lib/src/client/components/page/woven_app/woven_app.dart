import 'dart:html';
import 'dart:async';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_drawer_panel.dart';

import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/client/util.dart';
import 'package:woven/config/config.dart';

import 'package:woven/src/client/components/add_stuff/add_stuff.dart';
import 'package:woven/src/client/components/dialog/sign_in/sign_in.dart';

import 'package:firebase/firebase.dart' as db;


@CustomTag('woven-app')
class WovenApp extends PolymerElement with Observable {
  @published App app = new App();
  @observable var responsiveWidth = "600px";

  List<StreamSubscription> subscriptions = [];
  var f = new db.Firebase(config['datastore']['firebaseLocation']);

  WovenApp.created() : super.created();

  void switchPage(Event e, var detail, Element target) {
    togglePanel();
    app.router.dispatch(url: target.dataset['url']);
//    app.selectedPage = target.dataset['page'];
//    app.pageTitle = target.dataset['label'];
  }

  void scrollToTop() {
    app.scroller.scrollTop = 0;
  }

  void goBack(Event e, var detail, Element target) {
    // TODO: Clean this up.
    if (app.previousPage == 0) app.router.dispatch(url: (app.community != null ? '/${app.community.alias}' : '/'));
    if (app.previousPage == 5) app.router.dispatch(url: (app.community != null ? '/${app.community.alias}/events' : '/events'));
    (app.community != null) ? app.selectedPage = app.previousPage : app.selectedPage = 4;
  }

  signInWithFacebook() {
    app.signInWithFacebook();
  }

  void signOut() {
    HttpRequest.request(
        Routes.signOut.toString(),
        method: 'GET').then((_) {
      app.user = null;
      app.mainViewModel.invalidateUserState();
    });
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
    AddStuff addStuff = this.shadowRoot.querySelector('add-stuff');
    addStuff.toggleOverlay();

  }
// Toggle the sign in dialog.
  toggleSignIn() {
    SignInDialog signInDialog = this.shadowRoot.querySelector('sign-in-dialog');
    signInDialog.toggleOverlay();
  }

  attached() {
    // Whenever we load the app, try to see what's the current user (i.e. have we signed in?).
    HttpRequest.getString(Routes.currentUser.reverse([])).then((String contents) {
      var response = Response.fromJson(JSON.decode(contents));
      if (response.success && response.data != null) {
        app.authToken = response.data['auth_token'];
        f.authWithCustomToken(app.authToken).catchError((error) => print(error));

        // Set up the user object.
        app.user = UserModel.fromJson(response.data);
        app.cache.users[app.user.username] = app.user;

        // Trigger changes to app state in response to user sign in/out.
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
      print(record.name);

      print("changed from ${record.oldValue} (${record.oldValue.runtimeType}) to ${record.newValue} (${record.newValue.runtimeType})");

      // If page title changes, show it awesomely.
      if (record.name == new Symbol("pageTitle")) {
        print('pageTitle changed...');
        HtmlElement el;
        el = this.shadowRoot.querySelector('#page-title');
        if (el != null) {
          el.style.opacity = '0';
          new Timer(new Duration(milliseconds: 750), () {
            el.style.opacity = '1';
            el.text = (app.pageTitle != null) ? '${app.pageTitle}' : '';
          });
        }
      }

      // If brand new user, greet them.
      if (app.user != null && app.user.isNew == true) {
        greetUser();
        app.user.isNew = false;
      }
    });

    // A temporary place for some scripts I'm running.
    //
  }

  detached() {
    subscriptions.forEach((subscription) => subscription.cancel());
  }
}
