import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:woven/src/server/crawler/crawler.dart';
import 'package:woven/src/server/crawler/feed_reader.dart';
import 'package:woven/src/server/model/feed_item.dart';
import 'package:woven/src/server/crawler/open_graph.dart';
import 'package:woven/src/server/crawler/image_info.dart';
import 'package:woven/src/server/util/image_util.dart';
import 'package:woven/src/server/util/file_util.dart';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/util.dart' as sharedUtil;
import 'package:woven/src/server/util.dart';

import 'package:firebase/firebase_io.dart';
import 'package:logging/logging.dart';

final FirebaseClient firebase =
    new FirebaseClient(config['datastore']['firebaseSecret']);
String firebaseUrl = config['datastore']['firebaseLocation'];

main() async {
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
  getImages();
//testFeedCrawler();
}


testFeedCrawler() {

  List feeds = [
    'http://techcrunch.com/feed',
  'http://www.theverge.com/rss/full.xml',
  'http://miamiherald.typepad.com/the-starting-gate/rss.xml'
  ];

  feeds.forEach((feed) async {
    var feedReader = new FeedReader(url: feed);

    var results = await feedReader.load();

    results.forEach((FeedItem feedItem) {
      print('returned: ${feedItem.publicationDate} // ${feedItem.link}');
    });
  });
}

Future<ImageInfo> getBestImageFromHtml(String content) async {
  String url;
  List images;

  images = Crawler.findImagesAssociatedWithContent(content);
  images = await Crawler.removeSmallImages(images);

  Map<int, ImageInfo> goodImages = {};
  await Future.forEach(images, (imageUrl) async {

    ImageInfo imageInfo = await ImageInfo.parse(imageUrl);
    if (imageInfo.tooSmall) return;
    goodImages[imageInfo.size] = imageInfo;
  });

  if (goodImages.isEmpty) {
    var openGraph = OpenGraph.parse(content);
    ImageInfo imageInfo = await ImageInfo.parse(openGraph.imageUrl);
    return imageInfo;
  }
  ImageInfo bestImage = goodImages[goodImages.keys.reduce(max)];

  return bestImage;
}

getImages() async {
  var html = '';

  Directory dir = new Directory(Directory.current.parent.path + '/woven_test_files/pages');

  Stream<FileSystemEntity> list = dir.list(followLinks: false);

  await Future.forEach(await list.toList(), (FileSystemEntity entity) async {
    var file = new File(entity.path);

    if (!file.path.contains('.html')) return;

    ImageInfo imageInfo = await getBestImageFromHtml(await file.readAsString());

    print('''
BEST IMAGE: ${imageInfo.url}
FILE:${file.path}
FILENAME: ${imageInfo.filename}
EXTENSION: ${imageInfo.extension}
======
      ''');

    var fileName = sharedUtil.encodeFirebaseKey(imageInfo.url) + '.' + imageInfo.extension;
    var filePath = Directory.current.parent.path + '/woven_test_files/images/$fileName';

    File imageFile = new File(filePath);

    // Download the image locally to our temporary file.
    try {
      await downloadFileTo(imageInfo.url, imageFile);
    } catch(error) {
      print(error);
      return;
    }

//file:///Users/dave/Sites/woven_test_files/pages/http%253A%252F%252Fmiamiherald%252Etypepad%252Ecom%252Fthe-starting-gate%252F2015%252F11%252Fb%2525C3%2525BCro-group-opens-coconut-grove-co-working-center-its-fourth-location%252Ehtml.html
//file:///Users/dave/Sites/woven_test_files/pages/http%25253A%25252F%25252Fmiamiherald%25252Etypepad%25252Ecom%25252Fthe-starting-gate%25252F2015%25252F11%25252Fb%252525C3%252525BCro-group-opens-coconut-grove-co-working-center-its-fourth-location%25252Ehtml.html
    html = '''
$html
<div style="border-bottom:solid 2px black;margin-bottom:10px;">
 <img src="file://${Uri.encodeFull(imageFile.path)}">
  <p><a href="file://${Uri.encodeFull(entity.path)}" target="_blank">${entity.path}</a></p>
</div>
    ''';

  });

  File htmlFile = new File(Directory.current.parent.path + '/woven_test_files/index.html');
  htmlFile.writeAsString(html);
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
