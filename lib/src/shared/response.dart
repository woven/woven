library response;

import 'dart:convert';

class Response {
  bool success = true;
  Map data = {};

  Response([this.success = true]);

  String encode() {
    return JSON.encode({
      "success": success,
      "data": data
    });
  }

  static Response decode(String responseData) {
    var response = JSON.decode(responseData);

    return new Response()
      ..success = response['success']
      ..data = response['data'];
  }
}
