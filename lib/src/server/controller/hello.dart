library hello_controller;

import 'dart:io';
import '../app.dart';

class HelloController {
  static sayHello(App app, HttpRequest request, String person) {
    return 'Hello $person!';
  }

  static sayFoo(App app, HttpRequest request) {
    return 'foo!';
  }
}
