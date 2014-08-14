library main_controller;

import 'dart:io';
import '../app.dart';
import '../firebase.dart';
import '../../shared/response.dart';
import '../../shared/model/user.dart';
import '../../../config/config.dart';

class MainController {
  static serveApp(App app, HttpRequest request) {
    // If you return an instance of File, it will be served.
    return new File(config['server']['directory'] + '/index.html');
  }

  static getCurrentUser(App app, HttpRequest request) {
    var id = request.session['id'];
    if (id == null) return new Response(false);

    return Firebase.get('/users/$id.json').then((userData) {
      return new Response()
        ..data = userData;
    });
  }
}
