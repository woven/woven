import 'package:polymer/polymer.dart';
import 'package:angular/angular.dart';
import 'package:angular/application_factory.dart';
import 'package:angular_node_bind/angular_node_bind.dart';
import 'dart:html';
import 'dart:async';
import '../lib/components/inbox_list/inbox_list.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:core_elements/core_item.dart';

final f = new db.Firebase('https://luminous-fire-4671.firebaseio.com');

void main() {
  // Give the messageInput focus and listen for onClick
  _messageInput.focus();
  querySelector('#doButton').onClick.listen(doStuff);

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
doStuff(Event e) {
  //e.preventDefault();

  var message = _messageInput.value;

  // Is the following stuff in the right place? It only seems to work properly here.
  Future set(db.Firebase f) {
    //var setF = f.set({'date': '$now'});
    //f.push().set('$message').then((e) => print('Message sent: $message')); <-- could also do this one-liner
    var pushRef = f.push();
    var setF = pushRef.set('$message');
    return setF.then((e){print('Message sent: $message');});
  }

  set(f);

  _messageInput
    ..value = ''
    ..focus();
}