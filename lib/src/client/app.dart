library application;

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_animation.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/client/routing/router.dart';
import 'package:woven/src/shared/routing/routes.dart';
import 'dart:convert';

import 'package:crypto/crypto.dart';

class App extends Observable {
  @observable var selectedItem;
  @observable var selectedPage = 0;
  @observable String pageTitle = "";
  @observable UserModel user;
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
      // Decode the base64 URL and determine the item.
      var base64 = Uri.parse(path).pathSegments[1];
      var bytes = CryptoUtils.base64StringToBytes(base64);
      var decodedItem = UTF8.decode(bytes);
      window.alert("We're on an item: $decodedItem");
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

//  void changeTitle(newTitle) {
//    print("DEBUG: changeTitle");
//// TODO: This was breaking Safari
////    HtmlElement el;
////    el = document.querySelector('body /deep/ #page-title');
////    el.style.opacity = '0';
////    new Timer(new Duration(milliseconds: 1000), () {
////      pageTitle = newTitle;
////      el.style.opacity = '1';
////    });
//  }
}


