library firebase;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/config.dart';

class Firebase {
  static Future put(String path, data) {
    if (data is! String) data = JSON.encode(data);

    return http.post('${config['datastore']['firebaseLocation']}$path', body: data).then((response) {
      var message = JSON.decode(response.body);
      if (message['error'] != null) {
        throw 'Firebase returned an error.\nPath: $path\nData: $data\nResponse: ${message["error"]}';
      }

      print("We PUT something:\n$message");
    });
  }

  static Future<Map> get(String path) {
    return http.get('${config['datastore']['firebaseLocation']}$path').then((response) {
      var message = JSON.decode(response.body);
      if (message['error'] != null) {
        throw 'Firebase returned an error.\nPath: $path\nResponse: ${message["error"]}';
      }

      return message;
    });
  }
}
