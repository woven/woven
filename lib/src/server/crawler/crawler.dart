library crawler;

import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'dart:math';
import 'dart:mirrors';
import 'dart:collection';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'package:logging/logging.dart';

//import 'package:html5lib/parser.dart' as htmlParser;
//import 'package:html5lib/dom.dart';
//import 'package:html5lib/parser_console.dart';
//import 'package:path/path.dart' as path;
//import 'package:query_string/query_string.dart';

import '../util.dart' as util;

import 'package:woven/config/config.dart';
import 'package:woven/src/shared/util.dart';
import 'package:woven/src/server/util/image_util.dart';
import 'package:woven/src/server/util/file_util.dart';
import 'package:woven/src/shared/util.dart' as sharedUtil;
import 'package:woven/src/shared/model/uri_preview.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/src/server/crawler/open_graph.dart';
import 'package:woven/src/server/crawler/image_info.dart';
import 'package:woven/src/server/crawler/crawl_info.dart';

//import 'readability.dart';
//import 'open_graph/open_graph.dart';
//import 'model/server/models.dart' as model;
//import 'rss/rss.dart';
//import 'ical/ical.dart';

class Crawler {
  var app;
  String url;

  static const int MINIMUM_IMAGE_SIZE = 2000;

  final Logger logger = new Logger('Crawler');

  Crawler(this.url, {this.app}) {
    url = sharedUtil.prefixHttp(url);
  }

  Future<ImageInfo> getBestImageFromHtml(String content) async {
    logger.fine('Getting best image...');
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
      String contents = await http.read(uri);

      CrawlInfo crawlInfo = new CrawlInfo(uri: uri);

      var document = parse(contents);
      List<Element> metaTags = document.querySelectorAll('meta');

      metaTags.forEach((Element metaTag) {
        var property = metaTag.attributes['property'];

        if (property == 'og:title') crawlInfo.title =
            metaTag.attributes['content'];

        if (property == 'og:description') crawlInfo.teaser =
            metaTag.attributes['content'];

        if (metaTag.attributes['name'] == 'description' &&
            crawlInfo.teaser == null) crawlInfo.teaser =
            metaTag.attributes['content'];
      });

      if (crawlInfo.title == null &&
          document.querySelector('title') != null) crawlInfo.title =
          document.querySelector('title').innerHtml;

      // Let's get the best image ourselves, not from OG tags.
      crawlInfo.bestImage = await getBestImageFromHtml(contents);

      return crawlInfo;
    } catch (error) {
      // TODO: throw here!
      print('Exception in crawl():\n$error');
    }
  }

//  Future<Response> getPreview() async {
//    Response response = new Response();
//    Uri uri = Uri.parse(this.url);
//
//    try {
//      String contents = await http.read(uri);
//
//      UriPreview preview = new UriPreview(uri: uri);
//      var document = parse(contents);
//      List<Element> metaTags = document.querySelectorAll('meta');
//
//      metaTags.forEach((Element metaTag) {
//        var property = metaTag.attributes['property'];
//        if (property == 'og:title') preview.title =
//            metaTag.attributes['content'];
//        if (property == 'og:description') preview.teaser =
//            metaTag.attributes['content'];
//        if (property == 'og:image') preview.imageOriginalUrl =
//            metaTag.attributes['content'];
//
//        if (metaTag.attributes['name'] == 'description' &&
//            preview.teaser == null) preview.teaser =
//            metaTag.attributes['content'];
//      });
//
//      if (preview.title == null &&
//          document.querySelector('title') != null) preview.title =
//          document.querySelector('title').innerHtml;
//
//      response.data = preview.toJson();
//      return response;
//    } catch (error) {
//      return Response.fromError(error);
//    }
//  }
//
//  Future<Response> getPreviewOld() async {
//    Response response = new Response();
//    Uri uri = Uri.parse(this.url);
//
//    try {
//      // Visit the URL of this item and get the best image from its page.
//      var content = await http.get(this.url);
//      ImageInfo imageInfo = await getBestImageFromHtml(content.body);
//
//      // Download the image locally to our temporary file.
//      File imageFile = await downloadFileTo(imageInfo.url,
//          await createTemporaryFile(suffix: '.' + imageInfo.extension));
//
//      var imageUtil = new ImageUtil();
//      File croppedFile =
//          await imageUtil.resize(imageFile, width: 245, height: 120);
//
//      var extension = imageInfo.extension;
//      var gsBucket = config['google']['cloudStorage']['bucket'];
//      var gsPath = 'public/images/item/$itemId';
//
//      var filename = 'main-photo.$extension';
//      var cloudStorageResponse = await app.cloudStorageUtil.uploadFile(
//          croppedFile.path, gsBucket, '$gsPath/$filename',
//          public: true);
//
//      String contents = await http.read(uri);
//
//      UriPreview preview = new UriPreview(uri: uri);
//
//      // Get some basic info from the OG tags.
//      // TODO: Decouple to getOgInfo(String content)?
//      var document = parse(contents);
//      List<Element> metaTags = document.querySelectorAll('meta');
//
//      metaTags.forEach((Element metaTag) {
//        var property = metaTag.attributes['property'];
//
//        if (property == 'og:title') preview.title =
//            metaTag.attributes['content'];
//
//        if (property == 'og:description') preview.teaser =
//            metaTag.attributes['content'];
//
//        if (metaTag.attributes['name'] == 'description' &&
//            preview.teaser == null) preview.teaser =
//            metaTag.attributes['content'];
//      });
//
//      // Let's use the best image we found, not from the OG tags.
//      preview.imageOriginalUrl = imageInfo.url;
//
//      preview.imageSmallLocation = (cloudStorageResponse.name != null)
//          ? cloudStorageResponse.name
//          : null;
//
//      if (preview.title == null &&
//          document.querySelector('title') != null) preview.title =
//          document.querySelector('title').innerHtml;
//
//      response.data = preview.toJson();
//      return response;
//    } catch (error) {
//      return Response.fromError(error);
//    }
//  }

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

//  Future<model.Event> findEventDetails(String contents) {
//    return new Future(() {
//      var og = OpenGraph.parse(contents);
//
//      if (url.contains('facebook.com/events')) {
//        var match = new RegExp('facebook.com/events/([0-9]+)').firstMatch(url);
//        if (match != null) {
//          var eventId = match.group(1);
//
//          var clientId = Uri.encodeComponent(config['authentication']['facebook']['appId']);
//          var clientSecret = Uri.encodeComponent(config['authentication']['facebook']['appSecret']);
//
//          var url = 'https://graph.facebook.com/oauth/access_token?grant_type=client_credentials&client_id=$clientId&client_secret=$clientSecret';
//
//          return http.read(url).then((contents) {
//            var accessToken = Uri.encodeComponent(QueryString.parse('?$contents')['access_token']);
//
//            // Try to gather user info.
//            return http.read('https://graph.facebook.com/$eventId?access_token=$accessToken').then((contents) {
//              contents = JSON.decode(contents);
//
//              var futures = [];
//
//              var e = platform.databaseInstance.newInstance(model.Event)
//                ..title = contents['name']
//                ..description = contents['description'];
//
//              try {
//                e.location = contents['venue']['street'] + contents['venue']['city'];
//              } catch (e) {
//                print(e);
//              }
//
//              futures.add(util.parseDate(contents['start_time']).then((d) {
//                e.startDate = d;
//              }));
//
//              futures.add(util.parseDate(contents['end_time']).then((d) {
//                e.endDate = d;
//              }));
//
//              return Future.wait(futures).then((_) {
//                return e;
//              });
//            });
//          });
//        }
//      }
//
//      if (og == null) return;
//
//      if (og.siteName.toLowerCase() == 'eventbrite') {
//        // Probably a single event.
//        if (og.type != 'eventbriteog:organizer') {
//          var match = new RegExp('calendar\\?eid=([0-9]{5,})').firstMatch(contents);
//          if (match == null) return;
//
//          var eventId = match.group(1);
//          return util.readHttp('http://www.eventbrite.com/calendar.ics?eid=$eventId&calendar=ical').then((c) {
//            return iCal.parse(c).then((iCal ical) {
//              if (ical.events.length == 0) return;
//
//              iCalEvent e = ical.events.first;
//
//              return platform.databaseInstance.newInstance(model.Event)
//                ..startDate = e.startDate
//                ..endDate = e.endDate
//                ..location = e.location;
//            });
//          });
//        }
//      }
//    });
//  }

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
      var matchRss = new RegExp("<rss(.|[\n\r])*?version=\".*?\"",
          caseSensitive: false).firstMatch(contents);
      var matchAtom = new RegExp("<feed xmlns=[^]+?/Atom.",
          caseSensitive: false).firstMatch(contents);

      // The URL was a direct hit, return the url.
      if (matchRss != null || matchAtom != null) return url;

      // eventbrite.com/rss/organizer_list_events/4448338919
//      var og = OpenGraph.parse(contents);
//      if (og != null && og.siteName.toLowerCase() == 'eventbrite' && og.type == 'eventbriteog:organizer') {
//        // Find organizer ID.
//        var match = new RegExp('org/([0-9]+)').firstMatch(og.url);
//        if (match != null) {
//          return 'http://www.eventbrite.com/rss/organizer_list_events/${match.group(1)}';
//        }
//      }

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
    });
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

          if (logoWanted) {
            /*cssFutures.add(Crawler.getEntireCss(url: url, contents: contents).then((css) {
              var matches = new RegExp('url\\(["\']([^]*?)["\']\\)').allMatches(css);
              matches.forEach((match) {
                var url = match.group(1);
                if (url.contains('logo.')) {
                  logoUrls.add(url);
                }
              });
            }).catchError((e) {}));*/
          }

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
              } catch (e) {
                print(e);
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
                if (util.isSuccessStatusCode(response.statusCode) ==
                    false) return null;

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
              }).catchError((error) {
                print(error);
              });

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

//  static Future findImage({item, platform, skipImages: const []}) {
//
//  }

//  static Future fetchImage({article, event, platform, skipImages: const []}) {
//    return new Future(() {
//      var url;
//      if (article != null) url = article.url;
//      if (event != null) url = event.url;
//
//      if (url is List && url.length > 0) url = url.first;
//
//      if (url is List && url.length == 0) url = null;
//
//      if (url == null) return true;
//
//      return http.read(url).then((contents) {
//        OpenGraph og = OpenGraph.parse(contents);
//
//        var image;
//
//        Future process() {
//          return new Future(() {
//            return util.setItemImage(article: article, event: event, url: url, imagePath: image, platform: platform, skipImages: skipImages).then((_) => true).catchError((e) => false);
//          });
//        }
//
//        if (image == null || image.isEmpty || contents == null) {
//          return new Readability().parseFromUrl(url).then((r) {
//            image = r.imageUrl;
//            return process();
//          });
//        }
//
//        return process();
//      });
//    });
//  }

//  /**
//   * Returns all CSS for the site.
//   */
//  static Future getEntireCss({String url, String contents}) {
//    return new Future(() {
//      var css = '';
//
//      Future process() {
//        return new Future(() {
//          var futures = [];
//
//          var matches = new RegExp('<link([^]*?)>', caseSensitive: false).allMatches(contents);
//
//          matches.forEach((match) {
//            var urlMatch = new RegExp('href="(.*?)"').firstMatch(match.group(1));
//            if (urlMatch != null) {
//              var cssUrl = urlMatch.group(1);
//
//              if (Uri.parse(cssUrl).isAbsolute == false) {
//                var absoluteUrl = cssUrl;
//
//                if (url != null) {
//                  var uri = Uri.parse(url);
//                  absoluteUrl = uri.resolve(cssUrl);
//                }
//
//                futures.add(http.read(absoluteUrl).then((content) {
//                  css = '$css$content';
//                }));
//              }
//            }
//          });
//
//          return Future.wait(futures).then((_) => css).catchError((e) => css);
//        });
//      }
//
//      if (contents == null) {
//        url = util.prefixHttp(url);
//
//        return http.read(url).then((c) {
//          contents = c;
//
//          return process();
//        });
//      } else {
//        return process();
//      }
//    });
//  }

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
    } catch (e) {
//      platform.logger.severe(e);
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

        if (isValidUrl(img.attributes['src'])) images
            .add(img.attributes['src']);
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

//  static List<String> removeImagesWithBadExtensions(List<String> images) {
//    images.removeWhere((image) {
//      var sourcePath = Uri.parse(image).path;
//
//      if (path.extension(sourcePath) == '' || path.extension(sourcePath) == null) return false;
//
//      var mime = util.getMimeTypeFromExtension(sourcePath);
//      return mime.startsWith('image') == false;
//    });
//
//    return images;
//  }

  static Future<List<String>> removeSmallImages(List<String> images) {
    return new Future(() {
      var list = [];

      return Future.forEach(images, (image) async {
        var response = await http.head(image);
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
