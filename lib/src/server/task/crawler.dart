library woven.server.task.crawler;

import 'dart:async';
import 'dart:io';

import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import 'package:firebase/firebase_io.dart';

import 'package:woven/src/server/daemon/daemon.dart';
import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/shared/model/feed.dart';
import 'package:woven/src/shared/model/news.dart';
import 'package:woven/src/server/model/item.dart';
import 'package:woven/src/shared/util.dart' as util;
import 'package:logging/logging.dart';

import 'task.dart';
import '../util/file_util.dart';
import '../util/image_util.dart';
import '../util/cloud_storage_util.dart';
import '../task_scheduler.dart';
import 'package:woven/src/shared/input_formatter.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/server/crawler/crawler.dart';
import 'package:woven/src/server/crawler/feed_reader.dart';
import 'package:woven/src/server/model/feed_item.dart';
import 'package:woven/src/server/crawler/open_graph.dart';
import 'package:woven/src/server/crawler/image_info.dart';

class CrawlerTask extends Task {
  Daemon app;

//  bool runImmediately = true;
  Duration interval = const Duration(seconds: 120);

  final Logger logger = new Logger('CrawlerTask');

  FirebaseClient firebase =
      new FirebaseClient(config['datastore']['firebaseSecret']);
  String firebaseUrl = config['datastore']['firebaseLocation'];

  CrawlerTask(app) {
    this.app = app;
  }

  /**
   * Runs the task.
   */
  Future run() async {
    logger.info("Running the crawler task");

    Map communities =
        await firebase.get(Uri.parse('$firebaseUrl/communities.json'));

    communities.keys.forEach((community) async {
      Map feedsToCrawl = await firebase.get(Uri.parse(
          '$firebaseUrl/items_by_community_by_type/$community/feed.json'));

      if (feedsToCrawl == null) return;

      await Future.forEach(feedsToCrawl.values, (feedData) async {
        var feed = FeedModel.fromJson(feedData);

        var url = feed.url;
        var crawler = new Crawler(url);

        // Turns it into an actual feed URL, if it isn't already.
        // TODO: Store the feed URL or the user-entered URL or both in db?

        var feedUrl = await crawler.findFeedUrl();

        if (feedUrl == null) {
          logger.warning('No feed found for $url');
          return;
        }

        var feedReader = new FeedReader(url: feedUrl);
        var feedItems = await feedReader.load();

        if (feedItems.length == 0) {
          logger.warning('Empty or misunderstood feed found at $feedUrl');
          return;
        }

        var count = 0;
        await Future.forEach(feedItems, (FeedItem feedItem)  async {
          var encodedKey = util.encodeFirebaseKey(feedItem.link);
          // TODO: Tell kevmoo his encodeKey() not encoding properly.
//          print('$firebaseUrl/url_index/$encodedKey.json');
//          print('$firebaseUrl/url_index/${encodeKey(feedItem.link)}.json');
          try {
            var checkIfUrlExists = await firebase
                .get(Uri.parse('$firebaseUrl/url_index/$encodedKey.json'));

            if (checkIfUrlExists == null) {
              count++;
              logger.fine('Adding new item for ${feedItem.link}');

              var priority = -feedItem.publicationDate.millisecondsSinceEpoch;

              firebase.put(Uri.parse('$firebaseUrl/url_index/$encodedKey.json'),
                  {'lastCrawledDate': new DateTime.now().toUtc().toString()});

              // TODO: Crawl the feed item's URL, generate a uriPreview, etc.
              NewsModel newsItem = new NewsModel();
              newsItem
                ..url = feedItem.link
                ..subject = feedItem.title
                ..body = feedItem.description
                ..createdDate = feedItem.publicationDate
                ..updatedDate = feedItem.publicationDate
                ..user = 'dave'
                ..type = 'news'
                ..priority = priority;

              // TODO: Use firebase_io lib in ItemModel?
              var itemId = await Item.add(community, newsItem.toJson(),
                  config['datastore']['firebaseSecret']);

              newsItem.id = itemId;

              // Visit the URL of this item and get the best image from its page.
              var content = await http.get(feedItem.link);
              ImageInfo imageInfo =
                  await crawler.getBestImageFromHtml(content.body);

              // Download the image locally to our temporary file.
              File imageFile = await downloadFileTo(
                  imageInfo.url, await createTemporaryFile(suffix: '.' + imageInfo.extension));

              var imageUtil = new ImageUtil();
              File croppedFile =
                  await imageUtil.resize(imageFile, width: 245, height: 120);

              var extension = imageInfo.extension;
              var gsBucket = config['google']['cloudStorage']['bucket'];
              var gsPath = 'public/images/item/$itemId';

              var filename = 'main-photo.$extension';
              var cloudStorageResponse = await app.cloudStorageUtil.uploadFile(
                  croppedFile.path, gsBucket, '$gsPath/$filename',
                  public: true);

              UriPreview uriPreview =
                  new UriPreview(uri: Uri.parse(newsItem.url));
              uriPreview
                ..imageOriginalUrl = imageInfo.url
                ..imageSmallLocation = (cloudStorageResponse.name != null)
                    ? cloudStorageResponse.name
                    : null
                ..uri = Uri.parse(newsItem.url)
                ..title = newsItem.subject
                ..teaser =
                    InputFormatter.createIntelligentTeaser(newsItem.body);

              Map uriPreviewResponse = await firebase.post(
                  Uri.parse('$firebaseUrl/uri_previews.json'),
                  uriPreview.toJson());
              var uriPreviewId = uriPreviewResponse['name'];

              Item.update(newsItem.id, {'uriPreviewId': uriPreviewId},
                  config['datastore']['firebaseSecret']);

              imageFile.delete();
              croppedFile.delete();
            }
          } catch (e, s) {
            print('$e\n\n$s');
          }
        }).then((_) {
          if (count > 0) logger
              .info('Retrieved $count new items from $feedUrl');
        });
      }).catchError((error, stack) {
        logger.severe('Unhandled exception crawling feeds', error, stack);
      });
    });
  }

  Future getPreview(Uri uri) async {
    String contents = await http.read(uri);

    UriPreview preview = new UriPreview(uri: uri);
    var document = parse(contents);
    List<Element> metaTags = document.querySelectorAll('meta');

    metaTags.forEach((Element metaTag) {
      var property = metaTag.attributes['property'];
      if (property == 'og:title') preview.title = metaTag.attributes['content'];
      if (property == 'og:description') preview.teaser =
          metaTag.attributes['content'];
      if (property == 'og:image') preview.imageOriginalUrl =
          metaTag.attributes['content'];

      if (metaTag.attributes['name'] == 'description' &&
          preview.teaser == null) preview.teaser =
          metaTag.attributes['content'];
    });

    if (preview.title == null &&
        document.querySelector('title') != null) preview.title =
        document.querySelector('title').innerHtml;
  }
}
