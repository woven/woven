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
import 'controller/admin.dart';
import 'routing/router.dart';

import 'firebase.dart';

import 'package:woven/src/server/mailer/mailer.dart';


class App {
  Router router;
  VirtualDirectory virtualDirectory;
  Mailgun mailer;

  App() {
    // Start the server.
    HttpServer.bind(config['server']['address'], config['server']['port']).then(onServerEstablished, onError: printError);

    // Define what routes we have.
    router = new Router(this)
      ..routes[Routes.home] = MainController.serveApp
      ..routes[Routes.sayWelcome] = MainController.serveApp
      ..routes[Routes.showItem] = MainController.showItem
      ..routes[Routes.sayFoo] = HelloController.sayFoo
      ..routes[Routes.sayHello] = HelloController.sayHello
      ..routes[Routes.signInFacebook] = SignInController.facebook
      ..routes[Routes.currentUser] = MainController.getCurrentUser
      ..routes[Routes.starred] = MainController.serveApp
      ..routes[Routes.people] = MainController.serveApp
      ..routes[Routes.sendWelcome] = MainController.sendWelcomeEmail
      ..routes[Routes.sendNotifications] = MainController.sendNotifications
      ..routes[Routes.generateDigest] = AdminController.generateDigest;

    // Set up the virtual directory.
    virtualDirectory = new VirtualDirectory(config['server']['directory'])
      ..allowDirectoryListing = false
      ..jailRoot = false;

    // Set up emailing.
    mailer = new Mailgun();
  }

  void onServerEstablished(HttpServer server) {
    print("Server started.");

    server.listen((HttpRequest request) {
      // Some redirects if coming from related domains.
      if (request.headers.host == "mycommunity.org" || request.headers.host == "woven.org") {
        request.response.redirect(new Uri(scheme: 'http', host: 'woven.co', path: request.uri.path));
        return;
      }

      if (request.headers.host == "miamitech.org") {
        request.response.redirect(new Uri(scheme: 'http', host: 'woven.co', path: '/miamitech'));
        return;
      }

      // Rewrite URLs from relative to absolute so URLs
      // like /item/whatever properly load the app.
      // See http://goo.gl/Y5ERIY
      if (request.uri.path.contains('packages/')) {
        var path = request.uri.path.replaceFirst(new RegExp('^.*?packages/'), '');
        var file = new File(config['server']['directory'] + '/packages/$path');
        virtualDirectory.serveFile(file, request);
      } else if (request.uri.path.contains('static/')) {
        var path = request.uri.path.replaceFirst(new RegExp('^.*?static/'), '');
        var file = new File(config['server']['directory'] + '/static/$path');
        virtualDirectory.serveFile(file, request);
      // The following will handle either index.html or
      // post-build assets like index.html_bootstrap.dart.js etc.
      } else if (request.uri.path.contains('index.html')) {
        var path = request.uri.path.replaceFirst(new RegExp('^.*?index.html'), '');
        var file = new File(config['server']['directory'] + '/index.html$path');
        virtualDirectory.serveFile(file, request);
      } else if (request.uri.path.contains('index.dart')) {
        var path = request.uri.path.replaceFirst(new RegExp('^.*?index.dart'), '');
        var file = new File(config['server']['directory'] + '/index.dart$path');
        virtualDirectory.serveFile(file, request);
      // End of ugly relative/absolute handling.
      } else {
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
            // If no matching route, first let's try to serve a file.
            new File(config['server']['directory'] + request.uri.path).exists().then((bool exists) {
              if (!exists) {
                // File doesn't exist, so check if it's a community alias/
                if (Uri.parse(request.uri.path).pathSegments.length > 0) {
                  var alias;
                  alias = Uri.parse(request.uri.path).pathSegments[0];
                  // Wait for the aliasExists future to complete.
                  Future checkIfAliasExists = aliasExists(alias);
                  checkIfAliasExists.then((res) {
                    // If the alias exists, serve the app.
                    if (res == true) {
                      virtualDirectory.serveFile(new File(config['server']['directory'] + '/index.html'), request);
                    } else {
                      // No route, no alias, so pass off to request handler for standard 404 etc.
                      virtualDirectory.serveRequest(request);
                    }
                  });
                }
              } else {
                // File exists, so serve it.
                serveFileBasedOnRequest(request);
              }
            });
          }
        }).catchError((Exception error) {
          print(error);

          // The controller failed. Instead of crashing, just nicely show the error.
          request.response.statusCode = 500;
          request.response.headers.add(HttpHeaders.CONTENT_TYPE, "text/html");
          request.response.write('<h1>Internal server error</h1><p>${error.toString().replaceAll("\n", "<br />")}</p>');
          request.response.close();
        });
      }
    }, onError: printError);
  }

  aliasExists(String alias) {
    if (!new RegExp('^[a-zA-Z0-9_-]+\$').hasMatch(alias)) return new Future.value(false);

    return Firebase.get('/alias_index/$alias.json').then((res) {
      return (res == null ? false : true);
    });
  }

  void serveFileBasedOnRequest(HttpRequest req) {
    // We do not wish to output all those /packages/* stuff to the console. Ugly.
    if (!req.uri.path.contains('/packages')) print("${req.method} ${req.uri}");
    virtualDirectory.serveRequest(req);
  }

  void printError(error) => print("Error: $error");
}
