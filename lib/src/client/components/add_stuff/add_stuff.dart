import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import 'dart:math';
import 'package:firebase/firebase.dart' as db;
import 'package:core_elements/core_overlay.dart';
import 'package:woven/src/client/app.dart';
import 'package:woven/config/config.dart';
import 'package:core_elements/core_input.dart';
import 'package:core_elements/core_selector.dart';

@CustomTag('add-stuff')
class AddStuff extends PolymerElement {
  AddStuff.created() : super.created();
  @published App app;
  @published bool opened = false;

  CoreOverlay get overlay => $['overlay'];

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

    CoreSelector type = $['content-type'];
    CoreInput name = $['name'];
    CoreInput subject = $['subject'];
    CoreInput body = $['body'];

    if (subject.value.trim().isEmpty) {
      window.alert("Your message is empty.");
      return false;
    }

    var firebaseLocation = config['datastore']['firebaseLocation'];

    final items = new db.Firebase("$firebaseLocation/items");

    DateTime now = new DateTime.now().toUtc();

    Future set(db.Firebase items) {
      items.push().set({
          'user': name.inputValue,
          'subject': subject.inputValue,
          'type' : type.selected,
          'body': body.inputValue,
          'createdDate': '$now',
          'updatedDate': '$now'
      }).then((e){
//        print("Message sent: ${body.value}");
      });
    }

    set(items);
    overlay.toggle();
    body.value = "";
    subject.value = "";

    if (app.user != null) {
      app.user.username = name.inputValue;
    }

    app.selectedPage = 0;
  }

  attached() {
    print("+AddStuff");
  }
}

