class RegexHelper {
  static String domain = '[a-zA-Z0-9.-]+[a-zA-Z0-9-]';
  static String protocol = '[a-zA-Z]+:\\/\\/';
  static String www = 'www\\.';

  static String emailName = '[a-zA-Z.+]+';
  static String email = '\\b${emailName}@${domain}\\b';

  static String queryPath = '\\/[-~+=%_a-zA-Z0-9.]*[-~+=%_a-zA-Z0-9]';
  static String searchString = '\\?[-+=&;%@_.a-zA-Z0-9]*[-+=&;%@_a-zA-Z0-9]';
  static String queryHash = '#[-=_a-zA-Z0-9]+';

  static String link = '\\b($protocol|$protocol$www|$www)$domain($queryPath)*\\/?(\\/?$searchString)?($queryHash)?';

  static String linkOrEmail = '($email|$link)';
}