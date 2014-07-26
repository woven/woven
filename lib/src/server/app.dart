import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_server/http_server.dart';
import 'package:woven/config/config.dart';
import 'package:query_string/query_string.dart';

import '../shared/routing/routes.dart';
import 'controller/hello.dart';
import 'controller/main.dart';
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
      ..routes[Routes.sayFoo] = HelloController.sayFoo;

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
        } else if (response != null) {
          // A controller action responded with some data.
          request.response.write(response);
          request.response.close();
        } else {
          // No matching route, i.e. no response so far.
          serveFileBasedOnRequest(request);
        }
      });
    }, onError: printError);
  }

  /**
   * Handle Facebook login
   */
  void fbLogin(HttpRequest req) {
    print(req.uri.queryParameters['code']);
    print("-------");
    var code = Uri.encodeComponent(req.uri.queryParameters['code']);
    var appId = Uri.encodeComponent(config['authentication']['facebook']['appId']);
    var appSecret = Uri.encodeComponent(config['authentication']['facebook']['appSecret']);
    var url = Uri.encodeComponent(config['authentication']['facebook']['url']);


    http.read('https://graph.facebook.com/oauth/access_token?client_id=$appId&redirect_uri=$url&client_secret=$appSecret&code=$code').then((contents) {
      // "contents" looks like: access_token=USER_ACCESS_TOKEN&expires=NUMBER_OF_SECONDS_UNTIL_TOKEN_EXPIRES
      var parameters = QueryString.parse('?$contents');
      var accessToken = parameters['access_token'];

      // Try to gather user info.
      http.read('https://graph.facebook.com/me?access_token=$accessToken').then((contents) {
        Map user = JSON.decode(contents);

        print("""
---
The Facebook code is: ${user['id']}
---
      """);
        // Logged in as this user.

        saveUser(user);

        serveFileBasedOnRequest(req);


      });
    });
  }

  void saveUser(user) {
    var username = (user['username'] != null ? user['username'] : user['id']);
    var firstName = user['first_name'];
    var lastName = user['last_name'];
    var location = user['location']['name'];
    var facebookId = user['id'];

    var nameBody = '{"first": "$firstName", "last": "$lastName"}';
    var mainBody = '{"facebookId": "$facebookId", "username": "$username", "location": "$location"}';

    http.put('${config['datastore']['firebaseLocation']}/users/$username/name.json', body: nameBody).then((res) {
      print("We put something:\n${res.body}");
    });

    http.put('${config['datastore']['firebaseLocation']}/users/$username.json', body: mainBody).then((res) {
      print("We put something:\n${res.body}");
    });
  }


  /**
   * Handle POST requests
   * Return the same set of data back to the client.
   */
  void handlePost(HttpRequest req) {
    HttpResponse res = req.response;
    print('${req.method}: ${req.uri.path}');

//  addCorsHeaders(res);

    req.listen((List<int> buffer) {
      // return the data back to the client
      res.write('Thanks for the data. This is what I heard you say: ');
      res.write(new String.fromCharCodes(buffer));
      res.close();
    },
    onError: printError);
  }

  void serveFileBasedOnRequest(HttpRequest req) {
    // We do not wish to output all those /packages/* stuff to the console. Ugly.
    if (!req.uri.path.contains('/packages')) print("${req.method} ${req.uri}");

    virtualDirectory.serveRequest(req);
  }

  void printError(error) => print("Error: $error");
}
