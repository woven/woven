part of woven_server;

class ProfilePictureUtil {
  App app;

  ProfilePictureUtil(this.app);

  /**
   * Downloads profile picture from Facebook and returns the filename.
   *
   * Returns null if nothing good came up.
   */
  Future<String> downloadFacebookProfilePicture({String id, String user}) {
    return new Future(() {
      if (id == null) return null;

      // Download the profile picture.
      var profileDataUrl = 'https://graph.facebook.com/$id/picture?width=800&height=800&redirect=false';

      return http.read(profileDataUrl).then((contents) {
        var data = JSON.decode(contents);

        // No photo? Shame.
        if (data['data']['url'] == null) return null;
        if (data['data']['is_silhouette'] == true) return null;

        var extension = path.extension(data['data']['url']).split("?")[0];

        var imagePath = '.tmp/public/images/user/$user/profile-picture';
        var filename = 'profile-picture$extension';
        var fullPath = '$imagePath/$filename';
        var gsBucket = 'woven'; // TODO
        var gsPath = 'public/images/user/$user/profile-picture/$filename';

        return new Directory(imagePath).create(recursive: true).then((_) {
          return util.downloadFileTo(data['data']['url'], '$imagePath/$filename').then((_) {
            // Obtain an authenticated HTTP client which can be used for accessing Google
            // APIs. We identify this client application and request access for all scopes.
            // TODO: Move this to App?
            return auth.clientViaServiceAccount(app.googleServiceAccountCredentials, app.googleApiScopes).then((client) {
              var api = new storage.StorageApi(client);
              // Upload the file.
              return app.cloudStorageUtil.uploadFile(api, fullPath, gsBucket, gsPath, public: true)
              .whenComplete(() => client.close());
            }).catchError((error) {
              print("An unknown error occured: $error");
            });
          });
        });
      });
    });
  }
}