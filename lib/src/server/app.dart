library woven_server;

import 'dart:async';
import 'package:http_server/http_server.dart';
import 'package:woven/config/config.dart';

import '../shared/routing/routes.dart';

import 'controller/main.dart';
import 'controller/user.dart';
import 'controller/admin.dart';
import 'controller/mail.dart';
import 'routing/router.dart';

import 'firebase.dart';

import 'package:woven/src/server/mailer/mailer.dart';
import 'package:woven/src/server/task_scheduler.dart';

import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:woven/src/server/session_manager.dart';

// Add parts.
import 'package:woven/src/server/util/profile_picture_util.dart';
import 'package:woven/src/server/util/cloud_storage_util.dart';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors/shelf_cors.dart' as shelf_cors;
import 'package:shelf_static/shelf_static.dart' as shelf_static;

class App {
  Router router;
  VirtualDirectory virtualDirectory;
  Mailgun mailer;
  ProfilePictureUtil profilePictureUtil;
  CloudStorageUtil cloudStorageUtil;
  TaskScheduler taskScheduler;
  SessionManager sessionManager;

  final String serverPath = config['server']['path'];

  // Obtain the service account credentials from the Google Developers Console by
  // creating new OAuth credentials of application type "Service account".
  // This will give you a JSON file with the following fields.
  final googleServiceAccountCredentials =
      new auth.ServiceAccountCredentials.fromJson(
          config['google']['serviceAccountCredentials']);

  // This is the list of scopes this application will use.
  // You need to enable the Google Cloud Storage API in the Google Developers
  // Console.
  final googleApiScopes = [storage.StorageApi.DevstorageFullControlScope];

  final shelf.Handler staticHandler = shelf_static.createStaticHandler(
      config['server']['directory'],
      defaultDocument: 'index.html',
      serveFilesOutsidePath: true);

  // Holds the client authenticated for accessing Google APIs, which we instantiate below.
  var googleApiClient;

  App() {
    // Define what routes we have.
    router = new Router(this)
      ..routes[Routes.home] = MainController.serveApp
      ..routes[Routes.showItem] = MainController.showItem
//      ..routes[Routes.signInFacebook] = UserController.facebook
      ..routes[Routes.currentUser] = UserController.getCurrentUser
      ..routes[Routes.starred] = MainController.serveApp
      ..routes[Routes.people] = MainController.serveApp
      ..routes[Routes.sendNotificationsForItem] =
          MailController.sendNotificationsForItem
      ..routes[Routes.sendNotificationsForComment] =
          MailController.sendNotificationsForComment
      ..routes[Routes.getUriPreview] = MainController.getUriPreview
      ..routes[Routes.generateDigest] = AdminController.generateDigest
      ..routes[Routes.exportUsers] = AdminController.exportUsers
      ..routes[Routes.addItem] = MainController.addItem
      ..routes[Routes.addMessage] = MainController.addMessage
      ..routes[Routes.signIn] = UserController.signIn
      ..routes[Routes.signOut] = UserController.signOut
      ..routes[Routes.createNewUser] = UserController.createNewUser
      ..routes[Routes.confirmEmail] = MainController.confirmEmail
      ..routes[Routes.sendConfirmEmail] = MailController.sendConfirmEmail
      ..routes[Routes.inviteUserToChannel] = MailController.inviteUserToChannel;

    // Set up handlers for the server.
    var _handlerCascade = new shelf.Cascade()
        .add(_handleRoute)
        .add(_handleFile)
        .add(_handleAlias)
        .handler;

    var _handler = const shelf.Pipeline()
        .addMiddleware(shelf_cors.createCorsHeadersMiddleware())
//    .addMiddleware(shelf.logRequests())
        .addHandler(_handlerCascade);

    // Start the server.
    var address = config['server']['address'];
    var port = config['server']['port'];

    io.serve(_handler, address, port).then((server) {
      server.autoCompress = true;
      server.sessionTimeout = new DateTime.now()
              .add(new Duration(days: 365))
              .toUtc()
              .millisecondsSinceEpoch *
          1000;

      print('Serving at http://${server.address.host}:${server.port}');
    });

    // Set up some objects.
    profilePictureUtil = new ProfilePictureUtil(this);
    taskScheduler = new TaskScheduler(this);
    sessionManager = new SessionManager();

    taskScheduler.run();

    // Instantiate Google APIs is what follows.
    // Taken from example at: http://goo.gl/38YoIm

    // Obtain an authenticated HTTP client which can be used for accessing Google
    // APIs. We use `AccountCredentials` to identify this client application and
    // to request access for all scopes in `Scopes`.
    auth
        .clientViaServiceAccount(
            googleServiceAccountCredentials, googleApiScopes)
        .then((client) {
      this.googleApiClient = client;
      cloudStorageUtil = new CloudStorageUtil(googleApiClient);
    });
  }

  Future<shelf.Response> _handleFile(shelf.Request request) async {
    shelf.Response response = await this.staticHandler(request);
    response = response.change(headers: {'Transfer-Encoding': 'chunked'});
    return response;
  }

  Future<shelf.Response> _handleRoute(shelf.Request request) async {
    // Some redirects if coming from related domains.
    if (request.headers['host'] != null &&
        (request.headers['host'].contains("mycommunity.org") ||
            request.headers['host'].contains("woven.org"))) {
      return new shelf.Response.seeOther('http://woven.co');
    }

    if (request.headers['host'] != null &&
        (request.headers['host'].contains("miamitech.org"))) {
      return new shelf.Response.seeOther('http://woven.co/miamitech');
    }

    try {
//      shelf.Response response = new shelf.Response.ok('okkk');
      shelf.Response response = await router.dispatch(request);
      response = response.change(headers: {'Transfer-Encoding': 'chunked'});
      return response;
//      print('dispatch returned: ' + response.readAsString());
    } catch (error, trace) {
      print('$error\n\n$trace');

      // The controller failed. Instead of crashing, just nicely show the error.
      return new shelf.Response.internalServerError(
          body:
              '<h1>Internal server error</h1><p>${error.toString().replaceAll("\n", "<br />")}</p>');
    }
  }

  Future<shelf.Response> _handleAlias(shelf.Request request) async {
    if (Uri.parse(request.url.path).pathSegments.length > 0) {
      var alias = Uri.parse(request.url.path).pathSegments[0];

      if (await aliasExists(alias)) {
        var response =  staticHandler(new shelf.Request(
            'GET', Uri.parse(serverPath + '/')));
        response = response.change(headers: {'Transfer-Encoding': 'chunked'});
        return response;
      }
    }
    return new shelf.Response.notFound('That alias was not found.');
  }

  Future<bool> aliasExists(String alias) {
    if (!new RegExp('^[a-zA-Z0-9_-]+\$')
        .hasMatch(alias)) return new Future.value(false);

    return Firebase.get('/alias_index/$alias.json').then((res) {
      return (res == null ? false : true);
    });
  }

  void printError(error) => print("Error: $error");
}
