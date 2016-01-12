library router_client;

import 'dart:async';
import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:route/url_pattern.dart';

class Router extends Observable {
  StreamController _onDispatchController = new StreamController.broadcast();
  Stream get onDispatch => _onDispatchController.stream;

  StreamController _onNotFoundController = new StreamController();
  Stream get onNotFound => _onNotFoundController.stream;

  Map<UrlPattern, Function> routes = {};

  String get currentPath => window.location.pathname;

  @observable UrlPattern route;
  @observable var selectedItem;
  @observable var selectedPage;
  @observable var previousPage = null;

  var aliasHandler;

  Router() {
    // This is fired when the browser goes back or forward through the URL history.
    window.onPopState.listen((PopStateEvent e) {
      resolve();
    });

    Timer.run(resolve);
  }

  void switchPage(String url) {
    dispatch(url: '$url');
  }

  resolve() async {
    var matchingPattern = routes.keys.firstWhere(
        (UrlPattern pattern) => pattern.matches(currentPath),
        orElse: () => null);
    if (matchingPattern == null) {
      bool foundAlias = await aliasHandler(currentPath);
      if (foundAlias) {
        _onDispatchController.add(currentPath);
      } else {
        _onNotFoundController.add(currentPath);
      }
      return;
    }

    route = matchingPattern;

    _onDispatchController.add(currentPath);

    var action = routes[matchingPattern];
    if (action != null) action(currentPath); // Call the route handler.
  }

  void dispatch(
      {String url,
      String title,
      bool flash: false,
      bool alwaysDispatch: false}) {
    // Determine if we should just reload instead.
    if (Uri.parse(url).host != window.location.hostname &&
        Uri.parse(url).host != '') {
      window.location.href = url;
      return;
    }

    // An old trick from Woven -- flash the screen to make it look like as if it reloaded the page.
    if (flash) {
      document.body.style.visibility = 'hidden';
      new Timer(const Duration(milliseconds: 50), () {
        document.body.style.visibility = 'visible';
        document.body.scrollTop = 0;
      });
    }

    if (window.location.pathname == url && alwaysDispatch == false) {
      return;
    }

    if (History.supportsState == false) {
      window.location.assign(url);
      return;
    }

    if (title == null) title = document.title;

    window.history.pushState(null, title, url);
    resolve();
  }

//  I used this method like this in Woven:
//  <a href="/foo" title="Foo page" on-click="{{app.router.changePage}}">click here</a>
//  And it would automatically look into the event target's (<a>) title and href attributes
//  and do the rest to switch the URL.
  bool changePage(MouseEvent e) {
    if (e.button == 1) return true;

    // Find the anchor element.
    AnchorElement target = e.target;
    while (target != document.body && target is! AnchorElement) {
      target = target.parent;
    }

    var url = Uri.parse(target.attributes['href']).toString();
    var title = target.attributes['title'];

    if (url.startsWith('http') == true) return true;

    e.stopPropagation();
    e.preventDefault();

    dispatch(url: url, title: title);

    return false;
  }
}
