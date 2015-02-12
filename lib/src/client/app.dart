library application;

import 'package:polymer/polymer.dart';
import 'package:paper_elements/paper_toast.dart';
import 'dart:html';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/shared/model/community.dart';
import 'package:woven/src/client/routing/router.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/config/config.dart';
import 'package:woven/src/client/view_model/main.dart';
import 'package:core_elements/core_header_panel.dart';

class App extends Observable {
  @observable var selectedItem;
  @observable var selectedPage;
  @observable var previousPage = null;
  @observable String pageTitle = "";
  @observable UserModel user;
  @observable CommunityModel community;
  @observable bool hasTriedLoadingUser = false;
  @observable bool showHomePage = false;
  @observable bool skippedHomePage = false;
//  @observable bool isNewUser = false;
  Router router;
  MainViewModel mainViewModel;

  App() {
    mainViewModel = new MainViewModel(this);

    void home(String path) {
      // Home goes to the community list for now.
      selectedPage = 4;
      community = null;
      if (user == null && hasTriedLoadingUser && !skippedHomePage) showHomePage = true;
//      print('''
//      hasTriedLoadingUser: $hasTriedLoadingUser
//      skippedHomePage: $skippedHomePage
//      showHomePage: $showHomePage
//      ''');
    }

    void welcome(String path) {
      selectedPage = 4;
    }

    void starred(String path) {
      selectedPage = 2;
      pageTitle = "Starred";
    }

    void people(String path) {
      selectedPage = 3;
    }

    // We're using this as a kind of placeholder for various routes.
    void notFound(String path) {
      pageTitle = "Lobby";
      var pathUri = Uri.parse(path);
      if (pathUri.pathSegments.length == 1) {
        selectedPage = 0;
      } else {
//        print(pathUri.pathSegments[1]);
        // If we're at <community>/<something>, see if <something> is a valid page.
        switch (pathUri.pathSegments[1]) {
          case 'people':
            selectedPage = 3;
            break;
          case 'events':
            pageTitle = "Events";
            selectedPage = 5;
            break;
          case 'feed':
            pageTitle = "Feed";
            selectedPage = 7;
            break;
          case 'announcements':
            pageTitle = "Announcements";
            selectedPage = 6;
            break;
          default:
//            selectedPage = 0;
            print('404: ' + path);
        }
      }
    }

    void showItem(String path) {
      selectedPage = 1;
    }

    void globalHandler(String path) {
      if (config['debug_mode']) print("Global handler fired at: $path");

      /* TODO: Things like G tracking could be handled here. */
//      if (js.context['_gaq'] != null) {
//        js.context._gaq.push(js.array(['_trackPageview', path]));
//        js.context._gaq.push(js.array(['b._trackPageview', path]));
//      }

    }

    router = new Router()
    // Every route has to be registered... but if you don't need a handler, pass null.
      ..routes[Routes.home] = home
      ..routes[Routes.starred] = starred
      ..routes[Routes.people] = people
      ..routes[Routes.sayWelcome] = welcome
//      ..routes[Routes.anyAlias] = home
      ..routes[Routes.showItem] = showItem;

    router.onNotFound.listen(notFound);
    router.onDispatch.listen(globalHandler);

    // Use the first part of the path as the alias.
    var path = window.location.toString();
    if (Uri.parse(path).pathSegments.length > 0) {
      String alias = Uri.parse(path).pathSegments[0];

      // Get the community instance.
      var f = new db.Firebase(config['datastore']['firebaseLocation'] + '/communities/' + alias);

      f.onValue.first.then((e) {
        var communityData = e.snapshot.val();

        if (communityData != null) {
          community = new CommunityModel()
            ..createdDate = communityData['createdDate']
            ..alias = communityData['alias']
            ..name = communityData['name']
            ..shortDescription = communityData['shortDescription'];
        }

      });
    }
  }

   @observable bool get isMobile {
    if (isMobile == null) {
      //http://stackoverflow.com/questions/11381673/javascript-solution-to-detect-mobile-browser
      var a = window.navigator.userAgent;

      if (window.screen.width < 640 ||
      a.contains('Android') ||
      a.contains('webOS') ||
      a.contains('iPhone') ||
      a.contains('iPad') ||
      a.contains('iPod') ||
      a.contains('BlackBerry') ||
      a.contains('Windows Phone')
      ) {
        isMobile = true;
      } else {
        isMobile = false;
      }
    }

    return isMobile;
  }

  set isMobile(bool value) => isMobile = value;

  /**
   * Get the main scrolling element on app.
   */
  HtmlElement get scroller {
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

  void showMessage(String message, [String severity]) {
    PaperToast toastElement = document.querySelector('woven-app').shadowRoot.querySelector('#toast-message');
//    PaperToast toastElement = document.querySelector('woven-app::shadow #toast-message');
    if (severity == "important") {
      toastElement.classes.add("important");
    }
    toastElement.text = "$message";
    toastElement.show();
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

  void signInWithEmail() {
//    var signInUrl = 'https://www.facebook.com/dialog/oauth/?client_id=$appId&redirect_uri=$url&scope=email';
//    window.location.assign(signInUrl);
  }

}
