import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import '../lib/components/inbox_list/inbox_list.dart';
import 'package:firebase/firebase.dart' as db;

final f = new db.Firebase('https://luminous-fire-4671.firebaseio.com');

void main() {
  _messageInput.focus();
  querySelector('#doButton').onClick.listen(doStuff);

  // Placeholder for when we want to do stuff after Polymer elements fully loaded
  //TODO: What's a cleaner way to organize this?
  initPolymer().run(() {
    // code here works most of the time
    Polymer.onReady.then((_) {
      // some things must wait until onReady callback is called
      print("Polymer ready...");
    });
  });
}

// Called to make dartanalyzer happy
InputElement get _messageInput => querySelector('#messageInput');

doStuff(Event e) {
  e.preventDefault();

  var message = _messageInput.value;

  // Is the following stuff in the right place? It only seems to work properly here.
  Future set(db.Firebase f) {
    //var setF = f.set({'date': '$now'});
    var pushRef = f.push();
    var setF = pushRef.set('$message');
    return setF.then((e){print('Message sent: $message');});
  }

  set(f);

  _messageInput.value = '';
  _messageInput.focus();
}

