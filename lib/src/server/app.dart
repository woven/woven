import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_server/http_server.dart';
import 'package:woven/config/config.dart';
import 'package:query_string/query_string.dart';

import '../shared/routing/routes.dart';
import '../shared/response.dart';
import 'controller/hello.dart';
import 'controller/main.dart';
import 'controller/sign_in.dart';
import 'routing/router.dart';

class App {
  Router router;
  VirtualDirectory virtualDirectory;

  App() {
    // Start the server.
    HttpServer.bind(config['server']['address'], config['server']['port']).then(onServerEstablished, onError: printError);

    // Define what routes we have.
    router = new Router(this)
      ..routes[Routes.home] = MainController.home
      ..routes[Routes.sayFoo] = HelloController.sayFoo
      ..routes[Routes.sayHello] = HelloController.sayHello
      ..routes[Routes.signInFacebook] = SignInController.facebook
      ..routes[Routes.currentUser] = MainController.getCurrentUser;

    // Set up the virtual directory.
    virtualDirectory = new VirtualDirectory('web')
      ..allowDirectoryListing = false
      ..jailRoot = false;
  }

  void onServerEstablished(HttpServer server) {
    print("Server started.");

    server.listen((HttpRequest request) {
      router.dispatch(request).then((response) {
        if (response is File) {
          // A controller action responded with a File.
          virtualDirectory.serveFile(response, request);
        } else if (response is! NoMatchingRoute) {
          // 302 means redirection.
          if (request.response.statusCode != 302) {
            // null?
            if (response == null) response = 'The controller action returned null?';

            // If the action returned an instance of Response, then let's JSON encode it.
            // This is useful for AJAX and non-HTTP requests.
            if (response is Response) response = response.encode();

            // A controller action responded with some data.
            request.response.write(response);
          }

          request.response.close();
        } else {
          // No matching route, i.e. no response so far.
          serveFileBasedOnRequest(request);
        }
      }).catchError((Exception error) {
        print(error);

        // The controller failed. Instead of crashing, just nicely show the error.
        request.response.statusCode = 500;
        request.response.write('<h1>Internal server error</h1><p>${error.toString().replaceAll("\n", "<br />")}</p>');
        request.response.close();
      });
    }, onError: printError);
  }

  void serveFileBasedOnRequest(HttpRequest req) {
    // We do not wish to output all those /packages/* stuff to the console. Ugly.
    if (!req.uri.path.contains('/packages')) print("${req.method} ${req.uri}");

    virtualDirectory.serveRequest(req);
  }

  void printError(error) => print("Error: $error");
}
