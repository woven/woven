import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'file_util.dart';

import '../app.dart';

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
      var profileDataUrl = 'https://graph.facebook.com/$id/picture?width=1000&height=1000&redirect=false';

      return http.read(profileDataUrl).then((contents) {
        var data = JSON.decode(contents);

        // No photo? Shame.
        if (data['data']['url'] == null) return null;
        if (data['data']['is_silhouette'] == true) return null;

        var extension = path.extension(data['data']['url']).split("?")[0];

        var filename = 'profile-picture_orig$extension';
        var gsBucket = 'woven';
        var gsPath = 'public/images/user/$user/profile-picture/$filename';

        // Set up a temporary file to write to.
        return createTemporaryFile().then((File file) {
          // Download the file locally.
          return downloadFileTo(data['data']['url'], file).then((File file) {
            // Then upload the file to the cloud.
            return app.cloudStorageUtil.uploadFile(file.path, gsBucket, gsPath, public: true).then((res) {
              return file.delete().then((_) {
                return res;
              });
            });
          });
        });
      });
    });
  }
}