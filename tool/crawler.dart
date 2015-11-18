import 'dart:io';
import 'dart:async';

import 'package:woven/src/server/crawler/crawler.dart';
import 'package:woven/src/server/util/image_util.dart';
import 'package:woven/src/server/util/file_util.dart';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/util.dart' as sharedUtil;
import 'package:woven/src/server/util.dart';

import 'package:firebase/firebase_io.dart';

final FirebaseClient firebase =
    new FirebaseClient(config['datastore']['firebaseSecret']);
String firebaseUrl = config['datastore']['firebaseLocation'];

main() async {
  getImages();
}


String getBestImageFromContent(String content) async {

  List allImages = Crawler.findImagesAssociatedWithContent(await file.readAsString());

  List images = await Crawler.removeSmallImages(allImages);


}


getImages() {
  Directory dir = new Directory(Directory.current.parent.path + '/woven_test_files/pages');

  Stream<FileSystemEntity> list = dir.list(followLinks: false);

  list.forEach((entity) async {
    var file = new File(entity.path);

    if (!file.path.contains('.html')) return;

    String

    print('''
    ==================
    ${file.path}:
    ''');

    if (images.isEmpty) {
      print('''
       )))))))))))) EMPTY
       ${allImages.length}
       ))))))))))))
      ''');
    }


    images.forEach((image) {
      print(image);
    });
  });
}

getPreviews() async {
  // Get preview.
  Response response = await crawler.getPreview();
  print(response.data);
  UriPreview preview = UriPreview.fromJson(response.data);

//    if (preview.imageOriginalUrl == null ||
//        preview.imageOriginalUrl.isEmpty) return null;

  // Resize and save a small preview image.
  ImageUtil imageUtil = new ImageUtil();
  // Set up a temporary file to write to.
  File file = await createTemporaryFile();

  // Download the image locally to our temporary file.
  await downloadFileTo(preview.imageOriginalUrl, file);

  // Resize the image.
  //  File convertedFile = await imageUtil.resize(file, width: 225, height: 125);

  // Save the preview.
  print(convertedFile.path);
}


downloadPages() async {
  Map urls = await firebase.get(Uri.parse(
      '$firebaseUrl/url_index.json?orderBy="\$priority"&limitToFirst=50'));

  // Test crawler functionality.
  List testUris = urls.keys;

  testUris.forEach((String url) async {
    url = sharedUtil.decodeFirebaseKey(url);
    Crawler crawler = new Crawler(url);

    Uri uri = Uri.parse(url);

    // var contents = await readHttp(uri);

    var fileName = sharedUtil.encodeFirebaseKey(uri.toString());
    var filePath = Directory.current.parent.path + '/woven_test_files/pages/$fileName.html';

    File htmlFile = new File(filePath);

    // Download the image locally to our temporary file.
    try {
      await downloadFileTo(url, htmlFile);
    } catch(error) {
      print(error);
      return;
    }

    print(htmlFile.path);
  });
}
