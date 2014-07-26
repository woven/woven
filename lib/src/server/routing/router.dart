library router;

import 'dart:io';
import 'dart:async';
import 'dart:mirrors';
import 'package:route/url_pattern.dart';
import '../../shared/routing/routes.dart';
import '../app.dart';

class Router {
  App app;

  Map<UrlPattern, Function> routes = {};

  Router(this.app);

  Future dispatch(HttpRequest request) {
    return new Future(() {
      var matchingPattern = routes.keys.firstWhere((UrlPattern pattern) => pattern.matches(request.uri.path), orElse: () => null);

      if (matchingPattern == null) return new NoMatchingRoute();

      var action = routes[matchingPattern];
      ClosureMirror mirror = reflect(action);

      var arguments = [app, request];
      arguments.addAll(matchingPattern.parse(request.uri.path));

      try {
        var resultMirror = mirror.apply(arguments);
        return resultMirror.reflectee;
      } catch (e) {
        print('''Error: could not call the controller action: ${mirror.function.simpleName}\n
Tried to call with ${arguments.length} parameters: $arguments.
Are you sure the function signature is valid? Maybe you missed a parameter.''');
        return null;
      }
    });
  }
}
