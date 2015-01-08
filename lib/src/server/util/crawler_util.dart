library crawler_util;

import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html5lib/parser.dart' show parse;
import 'package:html5lib/dom.dart';
import 'package:woven/src/shared/model/uri_preview.dart';

class CrawlerUtil {
  CrawlerUtil();

  Future<UriPreview> getPreview(Uri uri) {
    return http.read(uri).then((String contents) {
      UriPreview preview = new UriPreview(uri: uri);
      var document = parse(contents);
      List<Element> metaTags = document.querySelectorAll('meta');

      metaTags.forEach((Element metaTag) {
        var property = metaTag.attributes['property'];
        if (property == 'og:title') preview.title = metaTag.attributes['content'];
        if (property == 'og:description') preview.teaser = metaTag.attributes['content'];
        if (property == 'og:image') preview.image = metaTag.attributes['content'];

        if (metaTag.attributes['name'] == 'description' && preview.teaser == null) preview.teaser = metaTag.attributes['content'];
      });

      return preview;
    });
  }
}