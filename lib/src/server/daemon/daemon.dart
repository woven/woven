library woven.server.daemon;

import 'dart:async';

import 'package:woven/config/config.dart';

import '../task_scheduler.dart';
import '../util/cloud_storage_util.dart';
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:googleapis_auth/auth_io.dart' as auth;


import 'package:logging/logging.dart';

class Daemon {
  auth.AutoRefreshingAuthClient googleApiClient;
  CloudStorageUtil cloudStorageUtil;

  Daemon() {
    print('The Woven daemon is now running...');

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((LogRecord rec) {
      print('${rec.level.name}: ${rec.time}: ${rec.message}');
      if (rec.error != null) print(rec.error);
      if (rec.stackTrace != null) print(rec.stackTrace);
    });

    initializeGoogleApiClient().then((googleApiClient) {
      cloudStorageUtil = new CloudStorageUtil(googleApiClient);
    });


    TaskScheduler taskScheduler = new TaskScheduler(this);

    taskScheduler.run();
  }

  // TODO: Move to util?
  Future<auth.AutoRefreshingAuthClient> initializeGoogleApiClient() async {
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

    // Instantiate Google APIs is what follows.
    // Taken from example at: http://goo.gl/38YoIm

    // Obtain an authenticated HTTP client which can be used for accessing Google
    // APIs. We use `AccountCredentials` to identify this client application and
    // to request access for all scopes in `Scopes`.
    auth.AutoRefreshingAuthClient client = await auth.clientViaServiceAccount(
        googleServiceAccountCredentials, googleApiScopes);
      this.googleApiClient = client;

    return client;
  }
}