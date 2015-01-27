import 'package:woven/src/server/util/crawler_util.dart';
import 'package:woven/src/server/util/image_util.dart';
import 'package:woven/src/server/util/file_util.dart';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'dart:io';

main() {
  // Test crawler functionality.
  List testUris = [
      'http://www.eventbrite.com/e/hispanicize-2015-march-16-20th-tickets-12902990191',
      'http://bigsummit.biz/'
    ];
  CrawlerUtil crawler = new CrawlerUtil();
  testUris.forEach((String uri) {
    crawler.getPreview(Uri.parse(uri)).then((UriPreview preview) {
      print(preview.title);
      print(preview.teaser);
      print(preview.imageOriginalUrl);
      print('---');

      if (preview.imageOriginalUrl == null) return null;

      // Resize and save a small preview image.
      ImageUtil imageUtil = new ImageUtil();
      // Set up a temporary file to write to.
      return createTemporaryFile().then((File file) {
        // Download the image locally to our temporary file.
        return downloadFileTo(preview.imageOriginalUrl, file).then((_) {
          // Resize the image.
          return imageUtil.resize(file, width: 225, height: 125).then((File convertedFile) {
            // Save the preview.
            print(convertedFile.path);
          });
        });
      });
    });
  });
}