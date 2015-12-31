library response;

import 'dart:convert';

class Response {
  bool success = true;
  Map data = null;
  String message = null;

  Response([this.success = true]);

  Map toJson() {
    return {
        'success': success,
        'message': message,
        'data': data
    };
  }

  static Response fromJson(Map data) {
    return new Response()
      ..success = data['success']
      ..message = data['message']
      ..data = data['data'];
  }

  static fromError(String error) {
    var response =  new Response()
      ..success = false
      ..message = error;
    return response;
  }
}
