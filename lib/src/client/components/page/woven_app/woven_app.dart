library woven_app;

import 'dart:html';
import 'dart:async';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_drawer_panel.dart';

import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/client/components/add_stuff/add_stuff.dart';

@CustomTag('woven-app')
class WovenApp extends PolymerElement with Observable {
  @published App app = new App();
  @observable var responsiveWidth = "600px";

  List<StreamSubscription> subscriptions = [];

  WovenApp.created() : super.created();

  void switchPage(Event e, var detail, Element target) {
    togglePanel();
    app.router.dispatch(url: target.dataset['url']);
  }

  void scrollToTop() {
    app.scroller.scrollTop = 0;
  }

  void goBack(Event e, var detail, Element target) {
    // TODO: Clean this up.
    if (app.router.previousPage == 'lobby') app.router.dispatch(url: (app.community != null ? '/${app.community.alias}' : '/'));
    if (app.router.previousPage == 'feed') app.router.dispatch(url: (app.community != null ? '/${app.community.alias}/feed' : '/feed'));
    if (app.router.previousPage == 'events') app.router.dispatch(url: (app.community != null ? '/${app.community.alias}/events' : '/events'));
    (app.community != null) ? app.router.selectedPage = app.router.previousPage : app.router.selectedPage = 'channels';
  }

  signInWithFacebook() => app.signInWithFacebook();

  signOut() => app.signOut();

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
      toggleSignIn();
      return;
    }

    if (app.community == null) {
      app.showMessage('Please go to a channel first.', 'important');
      return;
    }

    AddStuff addStuff = this.shadowRoot.querySelector('add-stuff');
    addStuff.toggleOverlay();

  }
// Toggle the sign in dialog.
  toggleSignIn() {
    app.toggleSignIn();
  }

  attached() async {
    // Whenever we load the app, try to see what's the current user (i.e. have we signed in?).
    try {
      var currentUser = await HttpRequest.getString(app.serverPath + Routes.currentUser.reverse([]));

      var response = Response.fromJson(JSON.decode(currentUser));
      if (response.success && response.data != null) {
        app.authToken = response.data['auth_token'];
        app.f.authWithCustomToken(app.authToken).catchError((error) => print(error));

        // Set up the user object.
        app.user = UserModel.fromJson(response.data);
        if (app.user.settings == null) app.user.settings = {};

        document.body.classes.add('no-transition');
        app.user.settings = toObservable(app.user.settings);
        new Timer(new Duration(seconds: 1), () => document.body.classes.remove('no-transition'));

        app.cache.users[app.user.username.toLowerCase()] = app.user;
      }

      app.hasTriedLoadingUser = true;

      // TODO: https://gist.github.com/kaisellgren/75f1aa96abb9c8cc56ae
      var user = app.user;
      if (user == null) {
        var path = window.location.pathname;
        app.showHomePage = path == '/' || path.contains('/confirm');
      } else {
        if (!user.disabled && user.onboardingState != 'temporaryUser') {
          if (user.onboardingState == 'signUpIncomplete') {
            app.showHomePage = true; // Show homepage regardless of path condition above.
            app.homePageCta = 'complete-sign-up';
          } else {
            app.showHomePage = false;

            // Trigger changes to app state in response to user sign in/out.
            //TODO: Aha! This triggers a feedViewModel load.
            app.mainViewModel.invalidateUserState();

            // On sign in, greet the user.
            if (app.user.isNew != true) Timer.run(() => greetUser());
          }
        } else {
          if (user.onboardingState == 'temporaryUser') {
            app.homePageCta = 'complete-sign-up';
          } else {
            app.homePageCta = 'disabled-note';
            app.user = null;
          }
        }
      }
    } catch(error, stack) {
      app.hasTriedLoadingUser = true;
      app.logError(error, stack);
    }

    // Listen for App changes so we can do some things.
    app.changes.listen((List<ChangeRecord> records) {
      PropertyChangeRecord record = records[0] as PropertyChangeRecord;

      if (app.debugMode) print("${record.name} changed from ${record.oldValue} (${record.oldValue.runtimeType}) to ${record.newValue} (${record.newValue.runtimeType})");

      // If page title changes, show it awesomely.
      if (record.name == new Symbol("pageTitle")) {
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
