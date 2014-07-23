import 'package:polymer/polymer.dart';
//import 'package:angular/angular.dart';
//import 'package:angular/application_factory.dart';
//import 'package:angular_node_bind/angular_node_bind.dart';
import 'dart:html';
import 'dart:math';
import 'dart:async';
export 'package:polymer/init.dart';
import 'package:woven/src/config.dart';

void main() {
  var fbConfig = config['authentication']['facebook'];
  var appId = fbConfig['appId'];
  var url = fbConfig['url'];

  var loginLinkUrl = 'https://www.facebook.com/dialog/oauth/?client_id=$appId&redirect_uri=$url&state=TEST_TOKEN&scope=email';


  // Placeholder for when we want to do stuff after Polymer elements fully loaded
  initPolymer().run(() {
    // Add the node_bind module for Angular
//    applicationFactory()
//      .addModule(new NodeBindModule())
//      .run();

    Polymer.onReady.then((_) {
      print("Polymer ready...");
    });
  });
}
