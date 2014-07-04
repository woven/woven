import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:firebase/firebase.dart';

var f = new Firebase('https://luminous-fire-4671.firebaseio.com');

void main() {
  querySelector('#HelloWorld').text = 'Hello world!';

  querySelector('#doStuff').onClick.listen(doStuff);

  print("Ready to roll...");


  initPolymer().run(() {
    // code here works most of the time
    Polymer.onReady.then((_) {
      // some things must wait until onReady callback is called
      // for an example look at the discussion linked below
      print("Polymer ready...");
    });
  });
}

void doStuff(_) {
  List items = querySelectorAll('.item-text');
  items.forEach((e) {
    e..text = "Yay we did it!";
  });

  // Is the following stuff in the right place? It only seems to work properly here.
  DateTime now = new DateTime.now();
  var message = querySelector('#message').value;

  Future setTest(Firebase f) {
    //var setF = f.set({'date': '$now'});
    var pushRef = f.push();
    var setF = pushRef.set('$message');
    return setF.then((e){print('Message sent: $message');});
  }

  setTest(f);
}