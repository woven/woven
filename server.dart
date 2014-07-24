import 'dart:io';
//import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_server/http_server.dart';
import 'dart:convert';
import 'package:woven/src/config.dart';
import 'package:query_string/query_string.dart';

void main() => WovenServer();

WovenServer() {
  HttpServer.bind('0.0.0.0', 8080).then(gotMessage, onError: printError);
}

gotMessage(HttpServer _server) {
  print("Listening...");
  print("Try http://${_server.address.address}:${_server.port}");

  _server.listen((HttpRequest req) {
    print("${req.method} ${req.uri};\tcached ${req.headers.ifModifiedSince}");

    switch (req.method) {
      case 'POST':
        //handlePost(request);
        break;
      case 'GET':
        // If code= let's assume it's a FB URL for now
        if (req.uri.queryParameters.containsKey("code")) {
          fbLogin(req);
        // else serve up static stuff. Not working at the moment.
        } else {
          staticHandler(req);
        }
        break;
      default:
        staticHandler(req);
    }
  },
  onError: printError); // .listen failed
}

void printError(error) => print("Error $error");

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

      staticHandler(req);


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

  //TODO: Where do I close the response?
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

void staticHandler(HttpRequest req) {
  var staticFiles = new VirtualDirectory('web')
    ..allowDirectoryListing = false
    ..jailRoot = false;

    staticFiles.serveRequest(req);
}

