library profile_picture_util;

import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'file_util.dart';
import 'image_util.dart';
import 'package:woven/src/shared/response.dart';

import '../app.dart';

class ProfilePictureUtil {
  App app;

  ProfilePictureUtil(app);

  /**
   * Downloads profile picture from Facebook to the cloud and returns the filename.
   *
   * Returns null if nothing good came up.
   */
  Future<Response> downloadFacebookProfilePicture({String id, String user}) {
    Map pictures = {};

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
        var gsBucket = 'woven';
        var gsPath = 'public/images/user/$user/profile-picture';

        // Set up a temporary file to write to.
        return createTemporaryFile().then((File file) {
          // Download the file locally.
          return downloadFileTo(data['data']['url'], file).then((File file) {
            var filename = 'profile-picture_orig$extension';

            // Save the original profile picture to the cloud.
            return app.cloudStorageUtil.uploadFile(file.path, gsBucket, '$gsPath/$filename', public: true).then((res) {
              pictures['original'] = (res.name != null ) ? res.name : null;

              // Create a small version of the profile picture.
              ImageUtil imageUtil = new ImageUtil();

              // Resize the image. Use double dimensions for retina displays.
              return imageUtil.resize(file, height: 80, width: 80).then((File convertedFile) {
                var filename = 'profile-picture_small$extension';

                // Save the small profile picture to the cloud.
                return app.cloudStorageUtil.uploadFile(convertedFile.path, gsBucket, '$gsPath/$filename', public: true).then((res) {
                  pictures['small'] = (res.name != null ) ? res.name : null;

                  file.delete();
                  convertedFile.delete();

                  var response = new Response();
                  response.data = pictures;
                  return response;
                });
              });
            });
          });
        });
      });
    });
  }
}