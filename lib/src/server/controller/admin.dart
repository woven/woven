library admin_controller;

import 'dart:io';
import '../app.dart';
import 'package:woven/src/server/digest/email_digest.dart';

class AdminController {
  static generateDigest(App app, HttpRequest request) {
    var community = request.requestedUri.queryParameters['community'];
    var from = request.requestedUri.queryParameters['from'];
    var to = request.requestedUri.queryParameters['to'];

    try {
      // Parse the strings.
      if (from != null) from = DateTime.parse(from);
      if (to != null) to = DateTime.parse(to);
    } catch(error) {
      return "Error parsing those dates: $error";
    }

    // Generate a new email digest.
    var digest = new EmailDigest(app);
    var digestOutput = digest.generateDigest(community, from: from, to: to);
    request.response.headers.contentType = ContentType.HTML;
    return digestOutput;
  }
}