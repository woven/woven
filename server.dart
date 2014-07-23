import 'dart:io';
//import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_server/http_server.dart';
import 'package:woven/src/config.dart';
import 'package:query_string/query_string.dart';

void main() => WovenServer();

WovenServer() {
  HttpServer.bind('0.0.0.0', 8080).then(gotMessage, onError: printError);
}

gotMessage(HttpServer _server) {
  print("Got here");
  _server.listen((HttpRequest request) {
    switch (request.method) {
      case 'POST':
        //handlePost(request);
        print("Post");
        break;
      case 'GET':
        // If code= let's assume it's a FB URL for now
        if (request.uri.queryParameters.containsKey("code")) {
          print("Has code!");

        // else serve up static stuff. Not working at the moment.
        } else {
          print("No code!");
          var staticFiles = new VirtualDirectory('web')
            ..allowDirectoryListing = false
            ..jailRoot = false;
          request.listen(staticFiles.serveRequest);
        }

//        handleGet(request, _server);
        break;
//      default: defaultHandler(request);
    default: print("Default!");
    }
  },
  onError: printError); // .listen failed
  print('Listening...');
}

void printError(error) => print("Error $error");

/**
 * Playing around. In flux.
 */

//void handleGet(HttpRequest request, HttpServer _server) {
//  if (request.uri.queryParameters['code'] != null) {
//
//    print(request.uri.queryParameters['code']);
//    var code = Uri.encodeComponent(request.uri.queryParameters['code']);
//    var appId = Uri.encodeComponent(config['authentication']['facebook']['appId']);
//    var appSecret = Uri.encodeComponent(config['authentication']['facebook']['appSecret']);
//    var url = Uri.encodeComponent(config['authentication']['facebook']['url']);
//
//
//    http.read('https://graph.facebook.com/oauth/access_token?client_id=$appId&redirect_uri=$url&client_secret=$appSecret&code=$code').then((contents) {
//      // "contents" looks like: access_token=USER_ACCESS_TOKEN&expires=NUMBER_OF_SECONDS_UNTIL_TOKEN_EXPIRES
//      var parameters = QueryString.parse('?$contents');
//      var accessToken = parameters['access_token'];
//
//      // Try to gather user info.
//      http.read('https://graph.facebook.com/me?access_token=$accessToken').then((contents) {
//        var user = JSON.decode(contents);
//
//        print(user);
//        // Logged in as this user.
//      });
//    });
//
//  } else {
//      print(_server);
//      defaultHandler(request, _server);
//  }
//
//
//}


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

void defaultHandler(HttpRequest request, HttpServer server) {
  var staticFiles = new VirtualDirectory('web')
    ..allowDirectoryListing = false
    ..jailRoot = false;

    print('Server running');
    server.listen(staticFiles.serveRequest);

}

