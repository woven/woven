//part of woven_client;
library dispatcher_client;

import 'dart:html';
import 'dart:async';
import 'dart:js' as js;
import 'package:polymer/polymer.dart';
import 'package:woven/src/config.dart';

class DispatcherClient /*extends Dispatcher*/ {
  var platform;
  var router;
  Stream onDispatch;
  StreamController _onDispatchController = new StreamController();

  DispatcherClient(this.router) {
    window.onPopState.listen((PopStateEvent e) {
      var address;

//      if (!platform.isMobile && e is PopStateEvent && e.state != null) {
//        address = e.state['url'];
//      }

      resolve(address: address);
    });

    onDispatch = _onDispatchController.stream.asBroadcastStream();
  }

  void resolve({address}) {
    platform.loadStuff(address: address);

    _onDispatchController.add(true);
  }

  void dispatch({url, title, alwaysRefresh: false, skipHistory: false, historyUrl, hiddenParameters, bool alwaysDispatch: false, bool resetScroll: true, onlyUpdateUrl: false}) {
    // Determine if we should just reload instead.
    if (Uri.parse(url).host != window.location.hostname && Uri.parse(url).host != '') {
      window.location.href = url;
      platform.showApplication = false;
      return;
    }

    if (alwaysRefresh) {
      document.body.style.visibility = 'hidden';
      new Timer(const Duration(milliseconds: 50), () {
        document.body.style.visibility = 'visible';
        document.body.scrollTop = 0;
      });
    }

    if (window.location.pathname == url && alwaysDispatch == false) return;

    if (History.supportsState == false) {
      window.location.assign(url);
      return;
    }

    // When user navigates anywhere, if there's an ongoing tutorial, reset it to 'beginning'.
    if (platform.user != null && platform.user.nextTutorial != null && platform.user.nextTutorial) {
      platform.user.nextTutorial == 'beginning';
    }

    if (title == null) title = platform.getTitle();

    if (hiddenParameters == null) hiddenParameters = {};

    if (window.location.pathname == url && alwaysDispatch) {
      window.history.replaceState({'skipHistory': skipHistory}, title, url);
    } else {
      window.history.pushState({'skipHistory': skipHistory}, title, url);
    }

    platform.router.hiddenParameters = hiddenParameters;

    if (onlyUpdateUrl == false) resolve();

//    if (js.context['_gaq'] != null) {
//      js.context._gaq.push(js.array(['_trackPageview', url]));
//      js.context._gaq.push(js.array(['b._trackPageview', url]));
//    }

    platform.setTitle(title);

    if (resetScroll) {
      Timer.run(() {
        Timer.run(() {
          platform.resetScroll(amount: 48);
        });
      });
    }

    //platform.refreshPage();
  }

  /**
   * A useful method to use in anchor on-click events.
   *
   * This cancels the default click event, and dispatches the new URL along with the anchor's title.
   */
  changePage(e, {bool alwaysRefresh: false, hiddenParameters, bool resetScroll: true, alwaysDispatch}) {
    // Let middle click work.
    if (e.button == 1) return true;

    // Find the anchor element.
    var target = e.target;
    while (target != document.body && target is! AnchorElement) {
      target = target.parent;
    }

    var url = target.attributes['href'];
    var title = target.attributes['title'];

    if (url.startsWith('http') == true) return true;

    e.stopPropagation();
    e.preventDefault();

    platform.dispatcher.dispatch(url: url, title: title, alwaysRefresh: alwaysRefresh, hiddenParameters: hiddenParameters, resetScroll: resetScroll, alwaysDispatch: alwaysDispatch);
  }
}