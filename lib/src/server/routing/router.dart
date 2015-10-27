library router_server;

import 'dart:async';
import 'dart:mirrors';

import 'package:route/url_pattern.dart';
import 'package:woven/src/shared/routing/routes.dart';
import '../app.dart';

import 'package:shelf/shelf.dart' as shelf;

class Router {
  App app;

  Map<UrlPattern, Function> routes = {};

  Router(this.app);

  Future dispatch(shelf.Request request) {
    return new Future(() {
      var matchingPattern = routes.keys.firstWhere((UrlPattern pattern) => pattern.matches(request.requestedUri.path), orElse: () => null);

      if (matchingPattern == null) return new shelf.Response.notFound('No matching route found');

      var action = routes[matchingPattern];
      ClosureMirror mirror = reflect(action);

      var arguments = [app, request];
      arguments.addAll(matchingPattern.parse(request.requestedUri.path));

      try {
        var resultMirror = mirror.apply(arguments);
        return resultMirror.reflectee;
      } catch (e, s) {
        print('''Error: could not call the controller action: ${mirror.function.simpleName}\n
Tried to call with ${arguments.length} parameters: $arguments.
Are you sure the function signature is valid? Maybe you missed a parameter.
\n\n$e\n\n$s''');
        return null;
      }
    });
  }
}