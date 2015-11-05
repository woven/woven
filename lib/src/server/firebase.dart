library firebase_server;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:woven/config/config.dart';

class Firebase {
  String auth;
  /**
   *
   * POST a new object to the location.
   *
   * Equivalent to a .push() in the Firebase client API.
   */
  static Future post(String path, data, {String auth}) async {
    if (data is! String) data = JSON.encode(data);

    http.Response response = await http.post(
        '${config['datastore']['firebaseLocation']}$path${(auth != null) ? '?auth=$auth' : ''}',
        body: data);

    Map message = JSON.decode(response.body);

    if (response.statusCode !=
        200) throw 'Firebase returned an error.\nPath: $path\nData: $data\nStatus code: ${response.statusCode}';

    if (message['name'] != null) return message['name'];
  }

  /**
   *
   * PUT and replace the object at the location.
   *
   * Equivalent to a .set() in the Firebase client API.
   */
  static Future put(String path, data, {String auth}) async {
    if (data is! String) data = JSON.encode(data);

    http.Response response = await http.put(
        '${config['datastore']['firebaseLocation']}$path${(auth != null) ? '?auth=$auth' : ''}',
        body: data);
    if (response.statusCode !=
        200) throw 'Firebase returned an error.\nPath: $path\nData: $data\nStatus code: ${response.statusCode}';
  }

  /**
   *
   * PATCH to update the object at the location.
   *
   * Equivalent to a .update() in the Firebase client API.
   */
  static Future patch(String path, data, {String auth}) async {
    if (data is! String) data = JSON.encode(data);
    var http = new HttpClient();
    var uri = Uri.parse(
        '${config['datastore']['firebaseLocation']}$path${(auth != null) ? '?auth=$auth' : ''}');

    try {
      HttpClientRequest request = await http.patchUrl(uri);
      request.headers.contentType =
          ContentType.JSON; // Without this, possible "String contains invalid characters."
      request.write(data);
      request.close();
      HttpClientResponse response = await request.done;

      if (response.statusCode !=
          200) throw 'Firebase returned an error.\nPath: $path\nData: $data\nStatus code: ${response.statusCode}';

      response.transform(UTF8.decoder).listen((contents) {
        return contents;
      });
//          return response.statusCode; // TODO: I want more here.

    } catch (error, stack) {
      print("Error: $error\n\n$stack");
    }
  }

  /**
   *
   * GET the object at the location.
   *
   * Returns a Map, or a String for simple values.
   */
  static Future get(String path) async {
    try {
      http.Response res =
          await http.get('${config['datastore']['firebaseLocation']}$path');

      if (res.statusCode !=
          200) throw 'Firebase returned an error.\nPath: $path\nStatus code: ${res.statusCode}';

      if (res.body != 'null') {
        var response = JSON.decode(res.body);

        return response;
      }
      return null;
    } catch (error, stack) {
      print("Error $error\n\n$stack");
    }
  }

  /**
   *
   * DELETE the object at the location.
   *
   * Equivalent to a .remove() in the Firebase client API.
   */
  static Future delete(String path, {String auth}) async {
    try {
      http.Response res = await http.delete(
          '${config['datastore']['firebaseLocation']}$path${(auth != null) ? '?auth=$auth' : ''}');

      if (res.statusCode !=
          200) throw 'Firebase returned an error.\nPath: $path\nStatus code: ${res.statusCode}';

      if (res.body != 'null') {
        var response = JSON.decode(res.body);

        return response;
      }
      return null;
    } catch (error, stack) {
      print("Error $error\n\n$stack");
    }
  }
}
