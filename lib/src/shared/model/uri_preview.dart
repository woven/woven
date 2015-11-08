library shared.model.uri_preview;

class UriPreview {
  Uri uri;
  String title;
  String teaser;
  String imageOriginalUrl;
  String imageSmallLocation;

  UriPreview({Uri uri}) {
    this.uri = uri;
  }

  /**
   * Dart calls this method when encoding this object with JSON.encode.
   */
  Map toJson() {
    return {
        'uri': uri.toString(),
        'title': title,
        'teaser': teaser,
        'imageOriginalUrl': imageOriginalUrl,
        'imageSmallLocation': imageSmallLocation
    };
  }

  static UriPreview fromJson(Map data) {
    if (data == null) return null;
    return new UriPreview()
      ..uri = data['uri']
      ..title = data['title']
      ..teaser = data['teaser']
      ..imageOriginalUrl = data['imageOriginalUrl']
      ..imageSmallLocation = data['imageSmallLocation'];
  }
}