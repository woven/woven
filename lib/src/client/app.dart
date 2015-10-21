library application;

import 'package:polymer/polymer.dart';
import 'package:paper_elements/paper_toast.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/shared/model/community.dart';
import 'package:woven/src/client/routing/router.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:firebase/firebase.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/view_model/main.dart';
import 'package:core_elements/core_header_panel.dart';
import 'package:woven/src/client/components/dialog/sign_in/sign_in.dart';
import 'dart:web_audio';
import 'cache.dart';
import 'util.dart';

class App extends Observable {
  @observable String pageTitle = "";
  @observable UserModel user;
  @observable CommunityModel community;
  @observable bool hasTriedLoadingUser = false;
  @observable bool showHomePage = true;
  @observable var homePageCta = 'sign-up';
  @observable bool skippedHomePage = false;
  DateTime timeOfLastFocus = new DateTime.now().toUtc();
  bool isFocused = true;
  bool debugMode;
  List reservedPaths = ['people', 'events', 'item', 'confirm'];
  final String serverPath = config['server']['serverPath'];

  Router router;
  MainViewModel mainViewModel;
  Cache cache;
  String authToken;
  String sessionId;
  Firebase f;
  String cloudStoragePath;
  AudioContext audioContext = new AudioContext();

  App() {
    f = new Firebase(config['datastore']['firebaseLocation']);
    cloudStoragePath = config['google']['cloudStoragePath'];

    mainViewModel = new MainViewModel(this);
    cache = new Cache();
    sessionId = readCookie('session');
    debugMode = (config['debug_mode'] != null ? config['debug_mode'] : false);

    // Track when app gets focus.
    window.onFocus.listen((_) {
      this.isFocused = true;
    });

    // Track when app loses focus.
    window.onBlur.listen((_) {
      this.isFocused = false;
      this.timeOfLastFocus = new DateTime.now().toUtc();
    });

    // Set up the router.
    router = new Router()
    // Every route has to be registered... but if we don't need a handler, pass null.
      ..routes[Routes.home] = home
      ..routes[Routes.starred] = starred
      ..routes[Routes.people] = people
      ..routes[Routes.showItem] = showItem
      ..routes[Routes.confirmEmail] = home;

    router.onNotFound.listen(notFound);
    router.onDispatch.listen(globalHandler);

    // On load, check to see if there's a community in the URL.
    // Use the first part of the path as the alias.
    var path = window.location.toString();
    if (Uri.parse(path).pathSegments.length > 0 && !reservedPaths.contains(Uri.parse(path).pathSegments[0])) {
      String alias = Uri.parse(path).pathSegments[0];
      f.child('/communities/$alias').once('value').then((res) {
        if (res == null) return;
        // If so, create a community object and add it to our cache.
        community = CommunityModel.fromJson(res.val());
        cache.communities[alias] = community;
      });
    }
  }

  void home(String path) {
    // Home goes to the community list for now.
    router.selectedPage = 'channels';
    changeCommunity(null);
    if (hasTriedLoadingUser && user == null && !skippedHomePage) showHomePage = true;
  }

  void starred(String path) {
    router.selectedPage = 'starred';
    pageTitle = "Starred";
  }

  void people(String path) {
    router.selectedPage = 'people';
  }

  // We're using this as a kind of placeholder for various routes.
  void notFound(String path) {
    var pathUri = Uri.parse(path);
    if (pathUri.pathSegments.length > 0) showHomePage = false;
    if (pathUri.pathSegments.length > 0 && !reservedPaths.contains(Uri.parse(path).pathSegments[0])) {
      String alias = Uri.parse(path).pathSegments[0];
      // Check the app cache for the community.
      changeCommunity(alias).then((bool success) {
        if (pathUri.pathSegments.length == 1) {
          router.selectedPage = 'lobby';
        } else {
          // If we're at <community>/<something>, see if <something> is a valid page.
          switch (pathUri.pathSegments[1]) {
            case 'people':
              pageTitle = "People";
              router.selectedPage = 'people';
              break;
            case 'events':
              pageTitle = 'Events';
              router.selectedPage = 'events';
              break;
            case 'news':
              pageTitle = 'News';
              router.selectedPage = 'news';
              break;
            case 'feed':
              pageTitle = 'Feed';
              router.selectedPage = 'feed';
              break;
            case 'announcements':
              pageTitle = 'Announcements';
              router.selectedPage = 'announcements';
              break;
            default:
              pageTitle = "default";
              print('404: ' + path);
          }
        }
      });
    }
  }

  void showItem(String path) {
//    router.previousPage = router.selectedPage;
    router.selectedPage = 'item';
  }

  void globalHandler(String path) {
    if (router.selectedPage != 'channels') showHomePage = false;

    if (this.debugMode) print("Global handler fired at: $path");

    /* TODO: Things like G tracking could be handled here. */
//      if (js.context['_gaq'] != null) {
//        js.context._gaq.push(js.array(['_trackPageview', path]));
//        js.context._gaq.push(js.array(['b._trackPageview', path]));
//      }
  }

  /**
   * Get the main scrolling element on app.
   */
  HtmlElement get scroller {
    //TODO: Get this working for chat view, which has its own scroller.
    CoreHeaderPanel el = document.querySelector("woven-app").shadowRoot.querySelector("#main-panel");
    HtmlElement scroller = el.scroller;
    return scroller;
  }

  // Unused for now.
  void resetCommunityTitle() {
    if (community !=null) {
      // Fade in the community title.
      // TODO: Fix this hack. We use a timer, because the element may not exist yet.
//      new Timer(new Duration(milliseconds: 750), () {
        HtmlElement sidebarTitleElement = document.querySelector('html /deep/ #sidebar-title');
        sidebarTitleElement.text = community.name;
        sidebarTitleElement.style.opacity = '1';
//      });
    }
  }

  void getUpdatedViewModels() {
    //
  }

  /**
   * Change the community.
   *
   * Set the community to null so we trigger an re-attach
   * for certain components that need to refresh their view model.
   */
  Future<bool> changeCommunity(String alias) {
    if (community != null && community.alias == alias) return new Future.value(true);

    if (alias == null) {
      community = null;
      return new Future.value(true);
    }

    // Check the app cache for the community...
    if (cache.communities.containsKey(alias)) {
      community = null;
      Timer.run(() => community = cache.communities[alias]);
    } else {
      // ...or query for the community.
      return f.child('/communities/$alias').once('value').then((res) {
        if (res == null) return false;
        cache.communities[alias] = CommunityModel.fromJson(res.val());
        community = null;
        Timer.run(() => community = cache.communities[alias]);
        return true;
      });
    }
    return new Future.value(true);
  }

  void showMessage(String message, [String severity]) {
    PaperToast toastElement = document.querySelector('woven-app').shadowRoot.querySelector('#toast-message');

    if (toastElement == null) return;

    if (toastElement.opened) toastElement.opened = false;

    new Timer(new Duration(milliseconds: 300), () {
      if (severity == "important") {
        toastElement.classes.add("important");
      } else {
        toastElement.classes.remove("important");
      }

      toastElement.text = "$message";
      toastElement.show();
    });
  }

  /**
   * Toggle the sign in dialog.
   */
  toggleSignIn() {
    SignInDialog signInDialog = document.querySelector('woven-app').shadowRoot.querySelector('sign-in-dialog');
    signInDialog.toggleOverlay();
  }

  void signInWithFacebook() {
    var cfg = config['authentication']['facebook'];
    var appId = cfg['appId'];
    // Unused: Grab the current URL so we can return the user after sign in.
    var returnPath = Uri.parse(window.location.toString()).path;
    var url = "${cfg['url']}";

    var signInUrl = 'https://www.facebook.com/dialog/oauth/?client_id=$appId&redirect_uri=$url&scope=email';
    window.location.assign(signInUrl);
  }

  @observable bool get isMobile {
    //http://stackoverflow.com/questions/11381673/javascript-solution-to-detect-mobile-browser
    var a = window.navigator.userAgent;
    bool _isMobile;

    if (window.screen.width < 640 ||
    a.contains('Android') ||
    a.contains('webOS') ||
    a.contains('iPhone') ||
    a.contains('iPad') ||
    a.contains('iPod') ||
    a.contains('BlackBerry') ||
    a.contains('Windows Phone')
    ) {
      _isMobile = true;
    } else {
      _isMobile = false;
    }

    return _isMobile;
  }
}
