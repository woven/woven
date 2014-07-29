import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'package:firebase/firebase.dart' as db;
import 'package:core_elements/core_overlay.dart';
import 'package:woven/src/client/app.dart';

@CustomTag('add-stuff')
class AddStuff extends PolymerElement {
  AddStuff.created() : super.created();
  @published App app;

  InputElement get name => $['name'];
  InputElement get subject => $['subject'];
  InputElement get body => $['body'];
  CoreOverlay get overlay => $['add-stuff-overlay'];

  // *
  // Toggle the overlay.
  // *
  toggleOverlay() {
    overlay.toggle();
//    name.focus(); //Doesn't work
  }

  // *
  // Add an item.
  // *
  addItem(Event e) {
    e.preventDefault();

    if (subject.value.trim().isEmpty) {
      window.alert("Your message is empty.");
      return false;
    }

    final items = new db.Firebase('https://luminous-fire-4671.firebaseio.com/items');

    DateTime now = new DateTime.now().toUtc();

    Future set(db.Firebase items) {
      items.push().set({
          'user': name.value,
          'subject': subject.value,
          'body': body.value,
          'createdDate': '$now'
      }).then((e){print('Message sent: ' + body.value);});
    }

    set(items);
    overlay.toggle();
    body.value = "";
    subject.value = "";

    //app.user = name.value;
    app.selectedPage = 0;
  }

  attached() {
    print("+AddStuff");
  }
}

