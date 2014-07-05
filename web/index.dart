import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'package:firebase/firebase.dart';
import 'package:../../lib/components/inbox_list/inbox_list.dart';

var f = new Firebase('https://luminous-fire-4671.firebaseio.com');

void main() {
  querySelector('#doButton').onClick.listen(doStuff);

  var doForm = querySelector('#doForm');
  doForm.onSubmit.listen((e) {
    print("Form was submitted...");
  });

  List inboxItems = new List();
  inboxItems = ['Cool','Awesome','Rad as heck', 'Lorem ipsum dwewedolot sit amet'];

//  f.onChildAdded.forEach((e) {
//    inboxItems.add(e.snapshot.val());
//  });

  print("Outside of initPolymer: $inboxItems");
  //print("Outside of initPolymer: $items");

  // Placeholder for when we want to do stuff after Polymer elements fully loaded
  //TODO: What's a cleaner way to organize this?
  initPolymer().run(() {
    // code here works most of the time
    Polymer.onReady.then((_) {
      // some things must wait until onReady callback is called

      f.onChildAdded.forEach((e) {
        //print(e.snapshot.val());
        inboxItems.add(e.snapshot.val());
      });

      print("Inside initPolymer: $inboxItems");

      print("Polymer ready...");
    });
  });

}


doStuff(Event e) {
  e.preventDefault();
  DateTime now = new DateTime.now();
  var message = querySelector('#messageInput').value;

  List items = querySelectorAll('.item-text');
  items.forEach((e) {
    e..text = "New message: $message";
  });

  print("Here they are:$inboxItems");

  // Is the following stuff in the right place? It only seems to work properly here.
  Future setTest(Firebase f) {
    //var setF = f.set({'date': '$now'});
    var pushRef = f.push();
    var setF = pushRef.set('$message');
    return setF.then((e){print('Message sent: $message');});
  }

  setTest(f);
}

