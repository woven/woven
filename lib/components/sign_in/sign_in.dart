import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';
import '../../src/app.dart';
import 'package:woven/src/config.dart';
import 'package:firebase/firebase.dart' as db;
import 'package:core_elements/core_overlay.dart';

@CustomTag('sign-in')
class SignIn extends PolymerElement {
  @published App app;
  @observable var showRegister = false;

  SignIn.created() : super.created();

  InputElement get username => $['username'];
  InputElement get password => $['password'];




  ButtonElement get button => $['button'];
  CoreOverlay get overlay => $['overlay'];

  var firebaseLocation = config['datastore']['firebaseLocation'];

  // *
  // Sign in the user.
  // *
  doSignin(Event e) {
    e.preventDefault();
    button..disabled = true
      ..text = "Wait...";

//    var f = new db.Firebase(firebaseLocation + '/items');
//    var checkUserQuery = f.limit(20);
  }

  // *
  // Create an account.
  // *
  doRegister(Event e) {
    InputElement registerUsername = $['register-username'];
  InputElement registerPassword = $['register-password'];
  InputElement firstName = $['first-name'];
  InputElement lastName = $['last-name'];
  InputElement email = $['email'];


    e.preventDefault();
    button..disabled = true
      ..text = "Wait...";

    DateTime createdDate = new DateTime.now().toUtc();

    //TODO: Check if user already exists
    //TODO: Secure the passwords
    print("""
    $firstName
    $lastName
    $registerUsername
    $registerPassword
    $email
    """);

    var user = new db.Firebase('$firebaseLocation/users/$username');

    Future set(db.Firebase user) {
      user.push().set({
          'username': registerUsername.value,
          'password': registerPassword.value,
          'name': {'first': firstName.value,'last': lastName.value},
          'createdDate': '$createdDate'
      }).then((e){print('User added: ' + username.value);});
    }

    set(user);
  }



  // *
  // Toggle the sign in dialog.
  // *
  toggleOverlay() {
    overlay.toggle();
  }

  toggleRegister() {
    HtmlElement el = $['toggle-register-link'];
    if (showRegister == false) {
      showRegister = true;
      el.text = "Sign in";
    } else {
      showRegister = false;
      el.text = "Create an account";
    }
  }
}





//TODO: Move this out and pass in a List with a Polymer attribute?

//getItems() {
//  var f = new db.Firebase(firebaseLocation + '/items');
//
//  // TODO: Undo the limit of 20; https://github.com/firebase/firebase-dart/issues/8
//  var lastItemsQuery = f.limit(20);
//  lastItemsQuery.onChildAdded.listen((e) {
//    var item = e.snapshot.val();
//    item['createdDate'] = DateTime.parse(item['createdDate']);
//
//    // snapshot.name is Firebase's ID, i.e. "the name of the Firebase location"
//    // So we'll add that to our local item list
//    item['id'] = e.snapshot.name();
//
//    // Insert each new item at top of list so the list is ascending
//    items.insert(0, item);
//  });
//}