part of mailer;

/**
 * This class represents an envelope that can be sent to someone/some people.
 */
class Envelope {
  String from = 'hello@woven.co';
  String to;
  String bcc;
  String subject;
  String text;
  String html;

  Future<Map> toMap() {
    if (html != null) {
      return {
          'from': from,
          'to': to,
          'bcc': bcc,
          'subject': subject,
          'html': html
      };
    }
    if (text != null) {
      return {
          'from': from,
          'to': to,
          'bcc': bcc,
          'subject': subject,
          'text': text
      };
    }
  }
}
