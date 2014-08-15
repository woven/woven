library application;

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_animation.dart';
import 'dart:html';
import 'dart:async';
import 'package:woven/src/shared/model/user.dart';
import 'package:woven/src/client/routing/router.dart';
import 'package:woven/src/shared/routing/routes.dart';

class App extends Observable {
  @observable var selectedItem;
  @observable var selectedPage = 0;
  @observable String pageTitle = "";
  @observable UserModel user;
  Router router;

  App() {
    void welcome(String path) {
      print('welcome!!');
    }

    void starred(String path) {
      print('starrred!!');
    }

    void notFound(String path) {
      print('404!' + path);
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
      ..routes[Routes.home] = null
      ..routes[Routes.starred] = starred
      ..routes[Routes.sayWelcome] = welcome;

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


