library hello_controller;

import 'dart:io';
import '../app.dart';

class HelloController {
  static String sayHello(App app, HttpRequest request, String person) {
    return 'Hello $person!';
  }

  static String sayFoo(App app, HttpRequest request) {
    return 'foo!';
  }
}
