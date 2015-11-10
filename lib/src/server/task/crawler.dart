library woven.server.task.crawler;

import 'dart:async';

import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;
import 'package:firebase/firebase_io.dart';

import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/shared/model/feed.dart';
import 'package:woven/src/shared/model/news.dart';
import 'package:woven/src/server/model/item.dart';
import 'package:woven/src/shared/util.dart' as util;

import 'task.dart';
import '../task_scheduler.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/server/crawler/crawler.dart';
import 'package:woven/src/server/crawler/feed_reader.dart';
import 'package:woven/src/server/model/feed_item.dart';

class CrawlerTask extends Task {
  bool runImmediately = true;

  final Map<String, List<String>> urlsToCrawl = {
    'miamitech': ['http://miamiherald.typepad.com/the-starting-gate/rss.xml'],
    'breakshop': []
  };

  FirebaseClient firebase =
      new FirebaseClient(config['datastore']['firebaseSecret']);
  String firebaseUrl = config['datastore']['firebaseLocation'];

  CrawlerTask();

  /**
   * Runs the task.
   */
  Future run() async {
    TaskScheduler.log("Running the crawler task");

    Map communities =
        await firebase.get(Uri.parse('$firebaseUrl/communities.json'));

    communities.keys.forEach((community) async {
      Map feedsToCrawl = await firebase.get(Uri.parse(
          '$firebaseUrl/items_by_community_by_type/$community/feed.json'));

      if (feedsToCrawl == null) return;

      Future.forEach(feedsToCrawl.values, (feedData) async {
        var feed = FeedModel.decode(feedData);

        var url = feed.url;
        var crawler = new Crawler(url);

        // Turns it into an actual feed URL, if it isn't already.
        // TODO: Store the feed URL or the user-entered URL or both in db?
        var feedUrl = await crawler.findFeedUrl();

        if (feedUrl == null) {
          TaskScheduler.log('No feed found for $url');
          return;
        }

        var feedReader = new FeedReader(url: feedUrl);
        var feedItems = await feedReader.load(limit: 2);

        if (feedItems.length == 0) return;
        feedItems.forEach((FeedItem feedItem) async {
          var encodedKey = util.encodeFirebaseKey(feedItem.link);
          print('$firebaseUrl/url_index/$encodedKey.json');
          print('$firebaseUrl/url_index/${encodeKey(feedItem.link)}.json');
          var checkIfUrlExists = await firebase.get(
              Uri.parse('$firebaseUrl/url_index/$encodedKey.json'));

          if (checkIfUrlExists == null) {

            firebase.put(
                Uri.parse(
                    '$firebaseUrl/url_index/$encodedKey.json'),
                {'lastCrawledDate': new DateTime.now().toUtc().toString()});

            // TODO: Crawl the feed item's URL, generate a uriPreview, etc.
            NewsModel newsItem = new NewsModel();
            newsItem
              ..url = feedItem.link
              ..subject = feedItem.title
              ..body = feedItem.description
              ..createdDate = new DateTime.now().toUtc()
              ..user = 'dave'
              ..type = 'news';

            // TODO: Use firebase_io lib in ItemModel?
            Item.add(community, newsItem.encode(), config['datastore']['firebaseSecret']);

          } else {
            TaskScheduler.log('URL already crawled: ${feedItem.link}');
          }
        });
      });
    });
  }

  // TODO: Unused atm.
  Future processFeed(Uri uri) async {
    String contents = await http.read(uri);
    print(contents);
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
