import 'package:polymer/polymer.dart';
import 'package:angular/angular.dart';
import 'package:angular/application_factory.dart';
import 'package:angular_node_bind/angular_node_bind.dart';
import 'dart:html';
import 'dart:math';
import 'dart:async';
import 'package:firebase/firebase.dart' as db;
import '../lib/components/inbox_list/inbox_list.dart';
import 'package:core_elements/core_item.dart';

var tempNames = ["Bob Dylan", "Jimi Hendrix", "Robert Plant", "Janice Joplin", "Nina Simone"];
var rng = new Random().nextInt(tempNames.length);
var tempUser = tempNames.elementAt(rng);

void main() {

  // Give the messageInput focus and listen for onClick
  _messageInput.focus();
  querySelector('#doButton').onClick.listen(addMessage);

  // Placeholder for when we want to do stuff after Polymer elements fully loaded
  initPolymer().run(() {
    // Add the node_bind module for Angular
    applicationFactory()
    .addModule(new NodeBindModule())
    .run();

    Polymer.onReady.then((_) {
      // Some things must wait until onReady callback is called
      print("Polymer ready...");

    });
  });
}

// Called to make dartanalyzer happy.
InputElement get _messageInput => querySelector('#messageInput');

// *
// This function called when the onClick.listen event above fires.
// It writes to the Firebase database and resets the messageInput's state.
// *
addMessage(Event e) {
  //e.preventDefault();

  if (_messageInput.value.trim().isEmpty) {
    window.alert("Your message is empty.");
    return;
  }

  final messages = new db.Firebase('https://luminous-fire-4671.firebaseio.com/nodes');

  var message = _messageInput.value;
  DateTime now = new DateTime.now().toUtc();

  // Is the following stuff in the right place? It only seems to work properly here.
  Future set(db.Firebase f) {

    f.push().set({'body': '$message', 'createdDate': '$now', 'user': '$tempUser'}).then((e){print('Message sent: $message');});

  }

  set(messages);

  _messageInput
    ..value = ''
    ..focus();
}