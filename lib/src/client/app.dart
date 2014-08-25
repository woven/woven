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
import 'package:woven/config/config.dart';


import 'package:crypto/crypto.dart';

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
      // Decode the base64 URL and determine the item.
      var base64 = Uri.parse(path).pathSegments[1];
      var bytes = CryptoUtils.base64StringToBytes(base64);
      var decodedItem = UTF8.decode(bytes);
      print("We're on an item: $decodedItem");

////      print(selectedItem);
//////      TODO: I guess I need to make the items list global somehow.
////      var item = items.firstWhere((i) => i['id'] == decodedItem);
////      app.selectedItem = item;
//
//      selectedItem = item;
//      selectedPage = 1;
//      print(item);

//      var firebaseLocation = config['datastore']['firebaseLocation'];

//      var f = new db.Firebase(firebaseLocation + '/items');

     /* TODO: I want to get the item as per the URL...
        but that item may not be in the local item list (called in InboxList.getItems)
        so we need to handle it separately. I could add the item to the local list
        but then I run the risk of having some older item randomly inserted into
        what is now the most recent items as per InboxList.getitems.
      */

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


