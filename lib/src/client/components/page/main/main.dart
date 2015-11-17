library client.components.page.app;

import 'dart:html';
import 'dart:async';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_drawer_panel.dart';
import 'package:core_elements/core_tooltip.dart';

import 'package:woven/src/client/app.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/client/components/add_stuff/add_stuff.dart';

@CustomTag('x-main')
class Main extends PolymerElement with Observable {
  @published App app;
  @observable var responsiveWidth = "600px";
  @observable var show = false;

  List<StreamSubscription> subscriptions = [];

  Main.created() : super.created();

  void switchPage(Event e, var detail, Element target) {
    app.router.switchPage(target.dataset['url']);
    Timer.run(() => togglePanel());
  }

  void scrollToTop() {
    app.scroller.scrollTop = 0;
  }

  void goBack(Event e, var detail, Element target) {
    // TODO: Clean this up.
    if (app.router.previousPage == 'lobby') app.router.dispatch(
        url: (app.community != null ? '/${app.community.alias}' : '/'));
    if (app.router.previousPage == 'feed') app.router.dispatch(
        url:
        (app.community != null ? '/${app.community.alias}/feed' : '/feed'));
    if (app.router.previousPage == 'events') app.router.dispatch(
        url: (app.community != null
            ? '/${app.community.alias}/events'
            : '/events'));
    (app.community != null)
        ? app.router.selectedPage = app.router.previousPage
        : app.router.selectedPage = 'channels';
  }

  signInWithFacebook() => app.signInWithFacebook();

  signOut() => app.signOut();

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

  changeTitle() {
    HtmlElement el;
    el = this.shadowRoot.querySelector('#page-title');
    if (el != null) {
      el.style.opacity = '0';
      new Timer(new Duration(milliseconds: 750), () {
        el.style.opacity = '1';
        el.text = (app.pageTitle != null) ? '${app.pageTitle}' : '';
      });
    } else {
      if (app.debugMode )print('DEBUG: pageTitle is NULL!');
    }
  }

  attached() async {
    changeTitle();

    app.router.onDispatch.listen((page) {
      print('DEBUG: Got onDispatch event');
      changeTitle();
    });
  }
}
