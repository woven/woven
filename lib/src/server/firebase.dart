library firebase_server;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/config.dart';

class Firebase {
  /**
   *
   * POST a new object to the location.
   *
   * Equivalent to a .push() in the Firebase client API.
   */
  static Future post(String path, data) {
    if (data is! String) data = JSON.encode(data);

    return http.post('${config['datastore']['firebaseLocation']}$path', body: data).then((response) {
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
  static Future put(String path, data) {
    if (data is! String) data = JSON.encode(data);

    return http.put('${config['datastore']['firebaseLocation']}$path', body: data).then((response) {
      var message = JSON.decode(response.body);
      if (message['error'] != null) {
        throw 'Firebase returned an error.\nPath: $path\nData: $data\nResponse: ${message["error"]}';
      }
    });
  }

  /**
   *
   * PUT and replace the object at the location.
   *
   * Equivalent to a .set() in the Firebase client API.
   */
  static Future<Map> get(String path) {
    return http.get('${config['datastore']['firebaseLocation']}$path').then((response) {
      if (response.body != 'null') {
        var message = JSON.decode(response.body);
        if (message['error'] != null) {
          throw 'Firebase returned an error.\nPath: $path\nResponse: ${message["error"]}';
        }
        return message;
      }

      return null;
    }).catchError((error) => print(error));
  }
}
