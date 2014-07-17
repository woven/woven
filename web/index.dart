import 'package:polymer/polymer.dart';
import 'package:angular/angular.dart';
import 'package:angular/application_factory.dart';
import 'package:angular_node_bind/angular_node_bind.dart';
import 'dart:html';
import 'dart:math';
import 'dart:async';
import 'package:firebase/firebase.dart' as db;
import '../lib/src/app.dart';

var tempNames = ["Bob Dylan", "Jimi Hendrix", "Robert Plant", "Janice Joplin", "Nina Simone"];
var rng = new Random().nextInt(tempNames.length);
var tempUser = tempNames.elementAt(rng);
var app = new App();

void main() {
  // Placeholder for when we want to do stuff after Polymer elements fully loaded
  initPolymer().run(() {
    // Add the node_bind module for Angular
    applicationFactory()
    .addModule(new NodeBindModule())
    .run();

    Polymer.onReady.then((_) {
      // Some things must wait until onReady callback is called
      print("Polymer ready...");
//      document.querySelector('#inbox-list').app = app;
//      document.querySelector('#item-preview').app = app;

//      new Timer.periodic(const Duration(seconds: 1), (_) {
//        print('Selected item:');
//        print(app.selectedItem);
//      });
    });
  });
}
