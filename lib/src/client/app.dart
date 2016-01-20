library application;

import 'dart:html';
import 'dart:async';
import 'dart:web_audio';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:paper_elements/paper_toast.dart';
import 'package:firebase/firebase.dart';
import 'package:core_elements/core_header_panel.dart';

import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/shared/model/community.dart';
import 'package:woven/src/client/routing/router.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/client/view_model/main.dart';
import 'package:woven/src/client/components/dialog/sign_in/sign_in.dart';
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
  bool debugMode =
      (config['debug_mode'] != null ? config['debug_mode'] : false);
  List reservedPaths = ['people', 'events', 'item', 'confirm'];
  final String serverPath = config['server']['path'];

  Router router;
  MainViewModel mainViewModel;
  Cache cache = new Cache();
  String authToken;
//  String sessionId;
  Firebase f = new Firebase(config['datastore']['firebaseLocation']);
  String cloudStoragePath = config['google']['cloudStorage']['path'];
  String cloudStorageBucket = config['google']['cloudStorage']['bucket'];
  AudioContext audioContext = new AudioContext();

  Stream onUserChanged;
  StreamController _controllerUserChanged;

  Stream onTitleChanged;
  StreamController _controllerTitleChanged;

  App() {
    mainViewModel = new MainViewModel(this);
//    sessionId = readCookie('session');

    // Track when app gets focus.
    window.onFocus.listen((_) {
      this.isFocused = true;
    });

    // Track when app loses focus.
    window.onBlur.listen((_) {
      this.isFocused = false;
      this.timeOfLastFocus = new DateTime.now().toUtc();
    });

    _controllerUserChanged = new StreamController();
    onUserChanged = _controllerUserChanged.stream.asBroadcastStream();
  }

  static Future<App> create() async {
    App app = new App();

    var t = new Stopwatch();
    t.start();
    await app.loadUserForSession();
    t.stop();
    print(t.elapsedMilliseconds);

    Uri currentPath = Uri.parse(window.location.toString());

    if (currentPath.pathSegments.contains('confirm') &&
        currentPath.pathSegments[1] != null) {
      app.homePageCta = 'complete-sign-up';
      app.hasTriedLoadingUser = true;
    } else {
      app.hasTriedLoadingUser = true;
    }

    await app.startRouter();


    print('''

8b      db      d8  ,adPPYba,  8b       d8  ,adPPYba,  8b,dPPYba,
`8b    d88b    d8' a8"     "8a `8b     d8' a8P_____88  88P'   `"8a
 `8b  d8'`8b  d8'  8b       d8  `8b   d8'  8PP"""""""  88       88
  `8bd8'  `8bd8'   "8a,   ,a8"   `8b,d8'   "8b,        88       88
    YP      YP      `"YbbdP"'      "8"      `"Ybbd88"  88       88

    ''');

    return app;
  }

  Future startRouter() async {
    // Set up the router.
    router = new Router()
      // Every route has to be registered... but if we don't need a handler, pass null.
      ..routes[Routes.home] = home
      ..routes[Routes.people] = people
      ..routes[Routes.showItem] = handleAliasPage
      ..routes[Routes.confirmEmail] = home
      ..aliasHandler = handleAliasPage;

    // On load, check to see if there's a community in the URL.
    // Use the first part of the path as the alias.
    var path = window.location.toString();
    if (Uri.parse(path).pathSegments.length > 0 &&
        !reservedPaths.contains(Uri.parse(path).pathSegments[0])) {
      String alias = Uri.parse(path).pathSegments[0];
      var checkAlias = await f.child('/communities/$alias').once('value');
      if (checkAlias == null) return;
      // If so, create a community object and add it to our cache.
      community = CommunityModel.fromJson(checkAlias.val());
      cache.communities[alias] = community;
    }

//    router.onNotFound.listen(notFound);
    router.onDispatch.listen(handleAliasPage);
  }

  void home(String path) {
    pageTitle = 'Channels';
    // Home goes to the community list for now.
    router.selectedPage = 'channels';
    changeCommunity(null);

    // Show the homepage if a signed out user had skipped it.
    if (hasTriedLoadingUser && user == null && !skippedHomePage) showHomePage =
        true;
  }

  void people(String path) {
    pageTitle = 'People';
    router.selectedPage = 'people';
  }

  // We're using this as a kind of placeholder for various routes.
  Future<bool> handleAliasPage(String path) {
    var pathUri = Uri.parse(path);

    if (pathUri.pathSegments.length > 0) showHomePage = false;

    if (pathUri.pathSegments.length > 0 &&
        !reservedPaths.contains(Uri.parse(path).pathSegments[0])) {
      String alias = Uri.parse(path).pathSegments[0];

      // Check the app cache for the community.
      return changeCommunity(alias).then((success) {
        if (!success) return false;

        if (pathUri.pathSegments.length == 1) {
          pageTitle = "Lobby";
          router.selectedPage = 'lobby';
        }

        if (pathUri.pathSegments.length > 1) {
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
              return false;
          }
        }
        return true;
      });
    }
    return new Future.value(false);
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
    DivElement scroller = document
        .querySelector("woven-app")
        .shadowRoot
        .querySelector("x-main")
        .shadowRoot
        .querySelector(".main");
    return scroller;
  }

  // Unused for now.
  void resetCommunityTitle() {
    if (community != null) {
      // Fade in the community title.
      // TODO: Fix this hack. We use a timer, because the element may not exist yet.
//      new Timer(new Duration(milliseconds: 750), () {
      HtmlElement sidebarTitleElement =
          document.querySelector('html /deep/ #sidebar-title');
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
    if (community != null &&
        community.alias == alias) return new Future.value(true);

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
    PaperToast toastElement = document
        .querySelector('woven-app')
        .shadowRoot
        .querySelector('x-main')
        .shadowRoot
        .querySelector('#toast-message');

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
    SignInDialog signInDialog = document
        .querySelector('woven-app')
        .shadowRoot
        .querySelector('x-main')
        .shadowRoot
        .querySelector('sign-in-dialog');
    signInDialog.toggleOverlay();
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

    showMessage("$greeting, ${user.firstName}.");
  }

  signOut() async {
    await HttpRequest.request(serverPath + Routes.signOut.toString(),
        method: 'GET');
    document.body.classes.add('no-transition');

    user = null;

    // Broadcast the user change to any listeners.
    _controllerUserChanged.add(user);

    new Timer(new Duration(seconds: 1),
        () => document.body.classes.remove('no-transition'));
  }

  loadUserForSession() {
    var userData = JSON.decode(document.querySelector('#user-data').text);

    if (userData != null) {
      // Set up the user object.
      user = UserModel.fromJson(userData);
      signIn();
    }
  }

  signIn() async {
    if (user == null) logError('Tried to sign in with null user.');
    if (user.settings == null) user.settings = {};

    document.body.classes.add('no-transition');
    user.settings = toObservable(user.settings);
    new Timer(new Duration(seconds: 1),
        () => document.body.classes.remove('no-transition'));

    cache.users[user.username.toLowerCase()] = user;

    try {
      // TODO: https://gist.github.com/kaisellgren/75f1aa96abb9c8cc56ae
      // TODO: Keep refactoring this!
      if (!user.disabled && user.onboardingState != 'temporaryUser') {
        if (user.onboardingState == 'signUpIncomplete') {
          // Show homepage regardless of path condition above.
          showHomePage = true;
          homePageCta = 'complete-sign-up';
        } else {
          showHomePage = false;
          skippedHomePage = true;

          // Broadcast the user change to any listeners.
          _controllerUserChanged.add(user);

          // On sign in, greet the user.
          if (user.isNew) {
            Timer.run(() => showMessage('Welcome to Woven, ${user.username}!'));
            user.isNew = false;
          } else {
            Timer.run(() => greetUser());
          }
        }
      } else {
        if (user.onboardingState == 'temporaryUser') {
          homePageCta = 'complete-sign-up';
        } else {
          homePageCta = 'disabled-note';
          user = null;
        }
      }
      hasTriedLoadingUser = true;
    } catch (error, stack) {
      hasTriedLoadingUser = true;
      logError(error, stack);
    }
  }

  void signInWithFacebook() {
    var cfg = config['authentication']['facebook'];
    var appId = cfg['appId'];
    // Unused: Grab the current URL so we can return the user after sign in.
    var returnPath = Uri.parse(window.location.toString()).path;
    var url = "${cfg['url']}";

    var signInUrl =
        'https://www.facebook.com/dialog/oauth/?client_id=$appId&redirect_uri=$url&scope=email';
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
        a.contains('Windows Phone')) {
      _isMobile = true;
    } else {
      _isMobile = false;
    }

    return _isMobile;
  }

  @observable bool get isNotMobile => !isMobile;

  logError(String error, [StackTrace stack]) =>
      window.console.error("$error\n\n${stack != null ? stack : ''}");
}
