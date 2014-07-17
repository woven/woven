import 'package:polymer/polymer.dart';
import 'package:angular/angular.dart';
import 'package:angular/application_factory.dart';
import 'package:angular_node_bind/angular_node_bind.dart';
import 'dart:html';
import 'dart:math';
import 'dart:async';

void main() {
  // Placeholder for when we want to do stuff after Polymer elements fully loaded
  initPolymer().run(() {
    // Add the node_bind module for Angular
    applicationFactory()
      .addModule(new NodeBindModule())
      .run();

    Polymer.onReady.then((_) {
      print("Polymer ready...");
    });
  });
}
