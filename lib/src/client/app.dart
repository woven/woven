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
  @observable var currentCommunity = "thelab";
  @observable var selectedItem;
  @observable var selectedPage = 0;
  @observable String pageTitle = "";
  @observable UserModel user;
  @observable CommunityModel community;
//  @observable bool isNewUser = false;
  Router router;

  App() {
    void home(String path) {
      selectedPage = 0;
    }

    void welcome(String path) {
      print('welcome!!');
    }

    void starred(String path) {
      selectedPage = 2;
      pageTitle = "Starred";
    }

    void people(String path) {
      selectedPage = 3;
    }

    void notFound(String path) {
      print('404!' + path);
    }

    void showItem(String path) {
      print("Show item");
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
        print(e.snapshot.val());
        print(communityData);

        if (communityData != null) {
          print("Got here");
          community = new CommunityModel()
            ..alias = communityData['alias']
            ..name = communityData['name']
            ..shortDescription = communityData['shortDescription'];

          // For now, assume all aliases are community aliases.
          currentCommunity = community.alias;
          print("Community: $communityData");
          print("1");
        }

      });
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


