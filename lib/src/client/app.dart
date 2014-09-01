library application;

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_animation.dart';
import 'package:paper_elements/paper_toast.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/shared/model/community.dart';
import 'package:woven/src/client/routing/router.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'dart:convert';
import 'package:firebase/firebase.dart' as db;
import 'package:woven/config/config.dart';

class App extends Observable {
  @observable var selectedItem;
  @observable var selectedPage = 0;
  @observable String pageTitle = "";
  @observable UserModel user;
  @observable CommunityModel community;
//  @observable bool isNewUser = false;
  Router router;

  App() {
    void home(String path) {
      print("Handler: home");
      selectedPage = 0;
      community = null;
    }

    void welcome(String path) {
      print('welcome!!');
    }

    void starred(String path) {
      selectedPage = 2;
      pageTitle = "Starred";
    }

    void people(String path) {
      print("Handler: people");
      selectedPage = 3;
    }

    void notFound(String path) {
      var pathUri = Uri.parse(path);
      if (community != null && pathUri.pathSegments[0] == community.alias) {
        print("The current community is in the path.");
        if (pathUri.pathSegments.length == 1) {
          print("The path doesn't have a secondary page, so go to the inbox.");
          selectedPage = 0;
        } else {
          // If we're at <community>/<something>, see if <something> is a valid page.
          switch (pathUri.pathSegments[1]) {
            case 'people':
              selectedPage = 3;
              break;
            default:
              print('404: ' + path);
          }
        }
      } else {
        print('404: ' + path);
      }
    }

    void showItem(String path) {
      selectedPage = 1;
    }

    void globalHandler(String path) {
      print("Global handler fired at: $path");

      /* TODO: Things like G tracking could be handled here.
      if (js.context['_gaq'] != null) {
        js.context._gaq.push(js.array(['_trackPageview', path]));
        js.context._gaq.push(js.array(['b._trackPageview', path]));
      }
      */
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
        Map communityData = e.snapshot.val();

        if (communityData != null) {
          community = new CommunityModel()
            ..alias = communityData['alias']
            ..name = communityData['name']
            ..shortDescription = communityData['shortDescription'];
        }

      });
    }
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

  // Show the toast message welcoming the user.
  void greetUser() {
    var greeting;
    DateTime now = new DateTime.now();

    if (now.hour < 12) {
      greeting = "Good morning";
    }
    else {
      if (now.hour >= 12 && now.hour <= 17) {
        greeting = "Good afternoon";
      }
      else if (now.hour > 17 && now.hour <= 24) {
        greeting = "Good evening";
      }
      else {
        greeting = "Hello";
      }
    }

    PaperToast toastMessage = document.querySelector('#toast-message');
    toastMessage.text = "$greeting, ${this.user.firstName}.";
    toastMessage.show();
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
}


