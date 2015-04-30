library regex_helper;

class RegexHelper {
  static String domain = '[a-zA-Z0-9.-]+[a-zA-Z0-9-]';
  static String protocol = '[a-zA-Z]+:\\/\\/';
  static String www = 'www\\.';
  static String port = '[:]*[0-9]*';

  static String emailName = '[a-zA-Z0-9-._+]';
  static String email = '\\b${emailName}@${domain}\\b';

  static String queryPath = '\\/[-~+=%!#@_a-zA-Z0-9.]*[-~+=%!#_a-zA-Z0-9]';
  static String searchString = '\\?[-+=&;%@_.a-zA-Z0-9]*[-+=&;%@_a-zA-Z0-9]';
  static String queryHash = '#[-=_a-zA-Z0-9]+';

  static String link = '\\b($protocol|$protocol$www|$www)$domain($port)($queryPath)*\\/?(\\/?$searchString)?($queryHash)?';

  static String linkOrEmail = '($email|$link)';

  static String mention = r'(^|\s+)(@[a-zA-Z0-9_-]+)((?=\s+)|$|[!?.,-:])';

  // Letters and and numbers allowed, but not just numbers.
  static String username = r'^\d*[a-zA-Z][a-zA-Z\d]*$';
}