library firebase_server;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/config.dart';

class Firebase {
  String auth;
  /**
   *
   * POST a new object to the location.
   *
   * Equivalent to a .push() in the Firebase client API.
   */
  static Future post(String path, data, {String auth}) {
    if (data is! String) data = JSON.encode(data);

    return http.post('${config['datastore']['firebaseLocation']}$path${(auth != null) ? '?auth=$auth' : ''}', body: data).then((response) {
      Map message = JSON.decode(response.body);
      if (message['error'] != null) {
        throw 'Firebase returned an error.\nPath: $path\nData: $data\nResponse: ${message["error"]}';
      }
      if (message['name'] != null) {
        return message['name'];
      }
    });
  }

  /**
   *
   * PUT and replace the object at the location.
   *
   * Equivalent to a .set() in the Firebase client API.
   */
  static Future put(String path, data, {String auth}) {
    if (data is! String) data = JSON.encode(data);

    return http.put('${config['datastore']['firebaseLocation']}$path${(auth != null) ? '?auth=$auth' : ''}', body: data).then((response) {
      var message = JSON.decode(response.body);
      if (message['error'] != null) {
        throw 'Firebase returned an error.\nPath: $path\nData: $data\nResponse: ${message["error"]}';
      }
    });
  }

  /**
   *
   * PATCH to update the object at the location.
   *
   * Equivalent to a .update() in the Firebase client API.
   */
  static Future patch(String path, data, {String auth}) {
    if (data is! String) data = JSON.encode(data);
    var http = new HttpClient();
    var uri = Uri.parse('${config['datastore']['firebaseLocation']}$path${(auth != null) ? '?auth=$auth' : ''}');

    try {
      return http.patchUrl(uri).then((HttpClientRequest request) {
        request.headers.contentType = ContentType.JSON; // Without this, possible "String contains invalid characters."
        request.write(data);
        request.close();
        return request.done.then((HttpClientResponse response) {
          response.transform(UTF8.decoder).listen((contents) {
            return contents;
          });
//          return response.statusCode; // TODO: I want more here.
        });
      });
    } catch(error, stack) {
      print("Error $error\n\n$stack");
    }
  }

  /**
   *
   * GET the object at the location.
   *
   * Returns a Map, or a String for simple values.
   */
  static Future get(String path) {
    return http.get('${config['datastore']['firebaseLocation']}$path').then((res) {
      if (res.body != 'null') {
        var response = JSON.decode(res.body);

        if (response is Map && response['error'] != null) {
          throw 'Firebase returned an error.\nPath: $path\nResponse: ${response["error"]}';
        }

        return response;
      }
      return null;
    }).catchError(print);
  }

  /**
   *
   * DELETE the object at the location.
   *
   * Equivalent to a .remove() in the Firebase client API.
   */
  static Future delete(String path, {String auth}) async {
    await http.delete('${config['datastore']['firebaseLocation']}$path${(auth != null) ? '?auth=$auth' : ''}');
    // TODO: Check for successful HTTP status and respond w/ it.
  }
}
