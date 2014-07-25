library router;

import 'package:polymer/polymer.dart';
import 'dart:convert';

/**
 * Responsible for determining controller actions, parse routes and generate routes.
 */
class Router {
  Map<String, String> previousParameters = toObservable({});
  Map<String, String> parameters = toObservable({});
  Map queryParameters = {};
  List restParameters = [];
  Map hiddenParameters = {};

  /**
   * The rules loaded from routing.json file.
   */
  List<Map> rules;

  Router(this.rules);

  /**
   * Resolves which routing rule matches the given type of request and URL.
   */
  Map resolve(String type, String url) {
    var matchingRule;

    parameters.clear();

    rules.forEach((Map rule) {
      // Try to see if the pattern matches the request path.
      var requestParts = url.split('/');
      var patternParts = rule['pattern'].split('/');

      requestParts.removeWhere((item) => item == '');
      patternParts.removeWhere((item) => item == '');

      // Initial check. Make sure both request and route pattern have same number of elements.
      var matches = requestParts.length == patternParts.length;

      if (matches) {
        // Make sure all parts of the URL match (route pattern matches with the request path).
        for (var i = 0, length = requestParts.length; i < length; i++) {
          // All parts of the URL must match.
          if (requestParts[i] != patternParts[i]) {

            // Exceptions are patterns with :foo URL parts. They always match.
            if (patternParts[i] != null && patternParts[i].startsWith(':')) {
              parameters[patternParts[i].replaceFirst(':', '')] = requestParts[i];
              continue;
            }

            matches = false;
            break;
          }
        }
      }

      // If the pattern matches.
      if (matches && rule['type'] == type) {
        matchingRule = rule;

        var extraParameters = rule.containsKey('parameters') ? rule['parameters'] : {};
        extraParameters.forEach((key, value) {
          parameters[key] = value;
        });
      }
    });

    if (matchingRule == null) {
      rules.forEach((Map rule) {
        if (rule['default'] == true && rule['type'] == type) {
          matchingRule = rule;
        }
      });
    }

    return matchingRule;
  }

  List<String> resolvePathToParts(String path) {
    parameters.clear();
    if (queryParameters == null) queryParameters = {};
    queryParameters.clear();
    restParameters.clear();

    var slices = path.split('?');

    var parts = slices[0].split('/');
    parts.removeWhere((item) => item == '');

    // The last part ended in a character ?
    if (parts.length > 0) {
      if (slices.length > 1) {
        var json = slices[1];

        try {
          queryParameters = JSON.decode(json);
        } catch (e) {
          queryParameters = {};
        }
      }

      parts.removeWhere((item) => item == null);
    }

    return parts;
  }

  Map getQueryParameters(String path) {
    var queryParameters = {};

    var slices = path.split('?');

    var parts = slices[0].split('/');
    parts.removeWhere((item) => item == '');

    // The last part ended in a character ?
    if (parts.length > 0) {
      if (slices.length > 1) {
        var json = slices[1];

        try {
          queryParameters = JSON.decode(json);
        } catch (e) {
          queryParameters = {};
        }
      }

      parts.removeWhere((item) => item == null);
    }

    return queryParameters;
  }
}