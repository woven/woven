library crawler;

import 'dart:math';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'package:logging/logging.dart';

import '../util.dart' as util;

import 'package:woven/src/shared/util.dart';
import 'package:woven/src/shared/util.dart' as sharedUtil;
import 'package:woven/src/server/crawler/open_graph.dart';
import 'package:woven/src/server/crawler/image_info.dart';
import 'package:woven/src/server/crawler/crawl_info.dart';

class Crawler {
  var app;
  String url;

  static const int MINIMUM_IMAGE_SIZE = 2000;

  static final Logger logger = new Logger('Crawler');

  Crawler(this.url, {this.app}) {
    url = sharedUtil.prefixHttp(url);
  }

  Future<ImageInfo> getBestImageFromHtml(String content) async {
    logger.fine('Getting best image');
    List images = [];

    images = Crawler.findImagesAssociatedWithContent(content);
    images = await Crawler.removeSmallImages(images);

    Map<int, ImageInfo> goodImages = {};
    await Future.forEach(images, (imageUrl) async {
      ImageInfo imageInfo = await ImageInfo.parse(imageUrl);
      if (imageInfo.tooSmall) return;
      goodImages[imageInfo.size] = imageInfo;
    });

    if (goodImages.isEmpty) {
      OpenGraph openGraph = OpenGraph.parse(content);
      ImageInfo imageInfo = await ImageInfo.parse(openGraph.imageUrl);
      return imageInfo;
    }

    ImageInfo bestImage = goodImages[goodImages.keys.reduce(max)];

    return bestImage;
  }

  Future<CrawlInfo> crawl() async {
    Uri uri = Uri.parse(this.url);

    try {
      String contents = await http.read(uri).catchError(
          (error, stack) => logger.severe('Error crawling URL', error, stack));

      CrawlInfo crawlInfo = new CrawlInfo(uri: uri);

      var document = parse(contents);
      List<Element> metaTags = document.querySelectorAll('meta');

      metaTags.forEach((Element metaTag) {
        var property = metaTag.attributes['property'];

        if (property == 'og:title')
          crawlInfo.title = metaTag.attributes['content'];

        if (property == 'og:description')
          crawlInfo.teaser = metaTag.attributes['content'];

        if (metaTag.attributes['name'] == 'description' &&
            crawlInfo.teaser == null)
          crawlInfo.teaser = metaTag.attributes['content'];
      });

      if (crawlInfo.title == null && document.querySelector('title') != null)
        crawlInfo.title = document.querySelector('title').innerHtml;

      // Let's get the best image ourselves, not from OG tags.
      crawlInfo.bestImage = await getBestImageFromHtml(contents);

      return crawlInfo;
    } catch (error, stack) {
      logger.severe('Exception in crawl()', error, stack);
    }
  }

  static String findGoogleCalendarUrlFromPage(String contents) {
    if (contents == null || contents == '') return null;

    var match = new RegExp('src="((.*?)google.com/calendar/embed(.*?))"')
        .firstMatch(contents);
    if (match == null) return null;

    var uri = Uri.parse(match.group(1));
    var src = uri.queryParameters['src'];
    var iCalUrl =
        'https://www.google.com/calendar/ical/${Uri.encodeComponent(src)}/public/basic.ics';

    return iCalUrl;
  }

  /**
   * Tries to find the RSS/ATOM feed URL.
   *
   * If the resulting URL is a HTML page, then try to find a reference to to the actual RSS/ATOM feed.
   */
  Future<String> findFeedUrl() {
    return util.readHttp(url).then((contents) {
      if (contents == null) return null;

      // Maybe the URL is already an iCal feed?
      if (contents.startsWith('BEGIN:VCALENDAR')) return url;

      // Try to look for RSS tag.
      var matchRss =
          new RegExp("<rss(.|[\n\r])*?version=\".*?\"", caseSensitive: false)
              .firstMatch(contents);
      var matchAtom =
          new RegExp("<feed xmlns=[^]+?/Atom.", caseSensitive: false)
              .firstMatch(contents);

      // The URL was a direct hit, return the url.
      if (matchRss != null || matchAtom != null) return url;

      // Let's see if we can find a RSS/ATOM URL from the output.
      // We find all <link> tags and then we check if any of them has "application/rss", etc.
      var regExp = new RegExp('<link.*?>', caseSensitive: false);
      var foundUrl;

      var matched = regExp.allMatches(contents).any((Match match) {
        if (match != null && match.group(0).contains('application/rss') ||
            match.group(0).contains('application/atom')) {
          var regExp = new RegExp('href=["\'](.*?)["\']', caseSensitive: false);

          var match2 = regExp.firstMatch(match.group(0));

          if (match2 != null) {
            var realFeedUrl = match2.group(1);

            if (realFeedUrl.trim().isEmpty) return null;

            if (realFeedUrl.startsWith('http') == false) {
              var extraSlash = '';
              if (url.endsWith('/') == false &&
                  realFeedUrl.startsWith('/') == false) extraSlash = '/';

              realFeedUrl = Uri.parse(url).resolve(realFeedUrl).toString();
            }

            foundUrl = realFeedUrl;
            return true;
          }
        }
      });

      if (matched == false) return null;

      return foundUrl;
    }).catchError(
        (error, stack) => logger.severe("Error in findFeedUrl", error, stack));
  }

  static Map imageSizes = {};

  /**
   * Returns the image size if it's big enough, otherwise false.
   */
  static Future<Map> getImageInfo(String url) async {
    Map imageInfo = {};

    return new Future(() async {
      // Check cache.
      if (imageSizes.containsKey(url)) {
        var size = imageSizes[url];
        if (size > Crawler.MINIMUM_IMAGE_SIZE) return size;

        return false;
      } else {
        var size;
        var head = await http.head(url);
        if (head.headers['content-length'] == null) {
          var get = await http.get(url);
          if (get.headers['content-length'] == null) {
            size = get.body.length;
          } else {
            size = get.headers['content-length'];
          }
        } else {
          size = head.headers['content-length'];
        }

        size = int.parse(size, onError: (_) => 0);

        if (size > Crawler.MINIMUM_IMAGE_SIZE) {
          imageSizes[url] = size;
          return size;
        } else {
          return false;
        }
      }
    });
  }

  /**
   * Finds the largest image on the HTML.
   *
   * This method looks for <img> tags, does a HEAD request to find the content length of the images.
   * The URL of the image with largest content size is returned.
   */
  static Future<String> getLargestImage(
      {String contents,
      String url,
      bool logoWanted: false,
      String skipContents}) {
    return new Future(() {
      if (contents == null && url == null) return null;

      url = sharedUtil.prefixHttp(url);

      Future continueProcessing(contents) {
        return new Future(() {
          if (contents == skipContents) return null;

          var futures = [], cssFutures = [];
          var largest = 0;
          var foundPreferred = false, foundCssLogo = false;
          var lastMatch;

          var urls = [], logoUrls = [];

          // Look for content="http:*"
          var matches =
              new RegExp('content="(http://.*?)"').allMatches(contents);
          matches.forEach((Match match) {
            var url = match.group(1);
            if (url.contains('logo')) {
              logoUrls.add(url);
            } else {
              urls.add(url);
            }
          });

          // Look for <img>'s
          var regExp = new RegExp('<img(.*?)/?>', caseSensitive: false);
          matches = regExp.allMatches(contents);
          matches.forEach((Match match) {
            var content = match.group(1);

            var regExp = new RegExp('src="(.*?)"', caseSensitive: false);
            var urlMatch = regExp.firstMatch(content);
            if (urlMatch != null) {
              var url = urlMatch.group(1);
              if (url.contains('logo')) {
                logoUrls.add(url);
              } else {
                urls.add(url);
              }
            }
          });

          // Links to other HTML pages such as frames, etc.
          var htmlUrls = [];
          matches = new RegExp('frame src="(http://.*?)"').allMatches(contents);
          matches.forEach((Match match) {
            htmlUrls.add(match.group(1));
          });

          return Future.wait(cssFutures).then((_) {
            var allUrls = [];
            logoUrls.forEach((u) => allUrls.add(u));
            urls.forEach((u) => allUrls.add(u));

            allUrls.sublist(0, min(allUrls.length, 5)).forEach((foundUrl) {
              if (foundPreferred) return null;

              try {
                // Make sure the URL is absolute.
                if (url != null &&
                    foundUrl != null &&
                    Uri.parse(foundUrl).isAbsolute == false) {
                  foundUrl = Uri.parse(url).resolve(foundUrl).toString();
                }
              } catch (error, stack) {
                logger.severe(
                    "Could not parse URL in getLargestImage", error, stack);
              }

              // Check cache.
              if (imageSizes.containsKey(foundUrl)) {
                var size = imageSizes[foundUrl];

                if (largest < size &&
                    size >= Crawler.MINIMUM_IMAGE_SIZE &&
                    foundPreferred == false) {
                  largest = size;
                  lastMatch = foundUrl;
                }

                if (size >= Crawler.MINIMUM_IMAGE_SIZE &&
                    foundPreferred == false &&
                    logoWanted == foundUrl.contains('logo')) {
                  foundPreferred = true;
                  largest = size;
                  lastMatch = foundUrl;
                }

                return null;
              }

              var f = http.head(foundUrl).then((response) {
                // Skip 404, etc.
                if (util.isSuccessStatusCode(response.statusCode) == false)
                  return null;

                if (response.headers['content-type'] == 'text/html') {
                  htmlUrls.add(foundUrl);
                } else {
                  var size = int.parse(response.headers['content-length']);

                  imageSizes[foundUrl] = size;

                  if (largest < size &&
                      foundPreferred == false &&
                      size >= Crawler.MINIMUM_IMAGE_SIZE) {
                    largest = size;
                    lastMatch = foundUrl;
                  }

                  if (size >= Crawler.MINIMUM_IMAGE_SIZE &&
                      foundPreferred == false &&
                      logoWanted == foundUrl.contains('logo')) {
                    foundPreferred = true;
                    largest = size;
                    lastMatch = foundUrl;
                  }
                }
              }).catchError((error, stack) =>
                  logger.severe('Error crawling URL', error, stack));

              futures.add(f);
            });

            return Future.wait(futures).then((values) {
              if (lastMatch != null || htmlUrls.length == 0) return lastMatch;

              return getLargestImage(
                      url: htmlUrls.first,
                      skipContents: contents,
                      logoWanted: logoWanted)
                  .then((imageUrl) => imageUrl)
                  .catchError((e) => null);
            });
          });
        });
      }

      if (contents != null) return continueProcessing(contents);

      return util.readHttp(url, requestAsChrome: true).then(continueProcessing);
    });
  }

  /**
   * Finds the best image related to the content.
   */
  static List findImagesAssociatedWithContent(String contents) {
    if (contents == null) return [];

    var images = [];
    var parentsWithMostParagraphs = {};

    Document dom;
    try {
      dom = parse(contents);
    } catch (error, stack) {
      logger.severe(
          'Could not parse contents in findImagesAssociatedWithContent...',
          error,
          stack);
      return images;
    }

    // Find all <p> tags, and count which of their parents have most <p>'s.
    dom.querySelectorAll('p').forEach((p) {
      if (parentsWithMostParagraphs.containsKey(p.parent) == false) {
        parentsWithMostParagraphs[p.parent] = 1;
      } else {
        parentsWithMostParagraphs[p.parent]++;
      }
    });

    // Choose parent with most <p>'s.
    var highest = 0;
    Element bestParentMatch;
    parentsWithMostParagraphs.forEach((parent, count) {
      if (count > highest) {
        highest = count;
        bestParentMatch = parent;
      }
    });

    if (bestParentMatch != null) {
      bestParentMatch.querySelectorAll('img').forEach((img) {
//        if (platform.adDetector.doesUrlPointToAd(img.attributes['src']) == false) {
        var href = img.parent.attributes['href'];
        if (href != null) {
          if (isValidUrl(href)) images.add(href);
        }

        if (isValidUrl(img.attributes['src']))
          images.add(img.attributes['src']);
      });
    }

    return images;
  }

  /**
   * Given a list of URLs, returns the first one that is actually an image.
   */
  static Future getFirstUrlWhichIsAnImage(List<String> urls) {
    return new Future(() {
      var index = -1;

      Future processNext() {
        return new Future(() {
          index++;

          if (urls.length <= index) return null;

          return http.head(urls[index]).then((response) {
            if (response.headers['content-type'].contains('image')) {
              return urls[index];
            }

            return processNext();
          }).catchError((e) {
            return processNext();
          });
        });
      }

      return processNext();
    });
  }

  static Future<List<String>> removeSmallImages(List<String> images) {
    return new Future(() {
      var list = [];

      return Future.forEach(images, (image) async {
        var response = await http.head(image).catchError((_) {
          return;
        });

        if (response == null) return;

        // Skip 404, etc.
        if (util.isSuccessStatusCode(response.statusCode) == false) return;

        if (response.headers['content-type'].startsWith('image')) {
          var length = response.headers['content-length'];
          if (length != null) {
            var size = int.parse(length);

            if (size >= Crawler.MINIMUM_IMAGE_SIZE) {
              list.add(image);
            }
          } else {
            list.add(image);
          }
        }
      }).then((_) => list);
    });
  }
}
