class UriPreview {
  Uri uri;
  String title;
  String teaser;
  String image;

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
        'image': image
    };
  }

  static UriPreview fromJson(Map data) {
    if (data == null) return null;
    return new UriPreview()
      ..uri = data['uri']
      ..title = data['title']
      ..teaser = data['teaser']
      ..image = data['image'];
  }
}