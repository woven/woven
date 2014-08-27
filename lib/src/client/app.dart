library application;

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_animation.dart';
import 'package:paper_elements/paper_toast.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/client/routing/router.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'dart:convert';
import 'package:firebase/firebase.dart' as db;

class App extends Observable {
  @observable var selectedItem;
  @observable var selectedPage = 0;
  @observable String pageTitle = "";
  @observable UserModel user;
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
    }

    void notFound(String path) {
      print('404!' + path);
    }

    void showItem(String path) {
      selectedPage = 1;
    }

    void globalHandler(String path) {
      print('example of a global handler for ANY url change: $path');

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
      ..routes[Routes.sayWelcome] = welcome
      ..routes[Routes.showItem] = showItem;

    router.onNotFound.listen(notFound);
    router.onDispatch.listen(globalHandler);
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
}


