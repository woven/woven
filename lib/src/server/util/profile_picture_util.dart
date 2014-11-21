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

        var filename = 'profile-picture$extension';

        var imagePath = 'web/static/images/user/${user}/';

        return new Directory(imagePath).create(recursive: true).then((_) {
          return util.downloadFileTo(data['data']['url'], '$imagePath$filename').then((_) {
              return filename;
          });
        });
      });
    });
  }
}