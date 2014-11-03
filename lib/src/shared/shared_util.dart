library shared_util;

String htmlDecode(String text) {
  if (text == null) {
    return '';
  }

  return text.replaceAll("&amp;", "&")
  .replaceAll("&lt;", "<")
  .replaceAll("&gt;", ">")
  .replaceAll("&quot;", '"')
  .replaceAll("&apos;", "'")
  .replaceAllMapped(new RegExp('&#([0-9]+);'), (Match match) {
    try {
      var value = int.parse(match.group(1));
      var character = new String.fromCharCode(value);

      return character;
    } catch (e) {
      return '';
    }
  }).replaceAllMapped(new RegExp('&#x([a-f0-9]+);'), (Match match) {
    try {
      var value = int.parse(match.group(1), radix: 16);
      var character = new String.fromCharCode(value);

      return character;
    } catch (e) {
      return '';
    }
  });
}