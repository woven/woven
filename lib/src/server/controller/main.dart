library main_controller;

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../app.dart';
import '../firebase.dart';
import '../../shared/response.dart';
import '../../shared/model/user.dart';
import '../../../config/config.dart';

class MainController {
  static serveApp(App app, HttpRequest request, [String path]) {
//    if (Uri.parse(request.uri.path).pathSegments.length > 1) {
//      // Check if the alias exists.
//      if (Uri.parse(request.uri.path).pathSegments[0].length > 0) {
//        var alias;
//        alias = Uri.parse(request.uri.path).pathSegments[0];
//        // Wait for the aliasExists future to complete.
//        print(alias);
//        Future checkIfAliasExists = aliasExists(alias);
//        checkIfAliasExists.then((res) {
//          // If the alias exists, serve the app.
//          if (res == true) {
//            // If you return an instance of File, it will be served.
//            return new File(config['server']['directory'] + '/index.html');
//          }
//        });
//      }
//    }

    return new File(config['server']['directory'] + '/index.html');
  }

  static showCommunity(App app, HttpRequest request, String community) {
    if (Uri.parse(community).pathSegments[0].length > 0) {
      community = Uri.parse(community).pathSegments[0];
      print(community);
      Firebase.get('/alias_index/$community.json').then((indexData) {
        if (indexData == null) {
          print("Alias wasn't found.");
          return;
        } else {
          var type = indexData['type'];
          print(type);
        }
      });
    }

    // If you return an instance of File, it will be served.
    return new File(config['server']['directory'] + '/index.html');
  }

  static showItem(App app, HttpRequest request, String item) {
    // Serve the app as usual, and client router will handle showing the item.
    // TODO: Apparently everything hear is infinite looping.
    return new File(config['server']['directory'] + '/index.html');
  }

  static getCurrentUser(App app, HttpRequest request) {
    var id = request.session['id'];
    if (id == null) return new Response(false);

    // Find the username associated with the Facebook ID
    // that's in session.id, then get that user data.
    return Firebase.get('/facebook_index/$id.json').then((indexData) {
      var username = indexData['username'];
      return Firebase.get('/users/$username.json').then((userData) {
        return new Response()
          ..data = userData;
      });
    });
  }

  static aliasExists(String alias) {
    Firebase.get('/alias_index/$alias.json').then((res) {
      return (res == null ? false : true);
    });
  }
}
