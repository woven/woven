library main_controller;

import 'dart:io';
import '../app.dart';

class MainController {
  static File home(App app, HttpRequest request) {
    // If you return an instance of File, it will be served.
    return new File('web/index.html');
  }
}
