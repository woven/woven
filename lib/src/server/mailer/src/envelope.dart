part of mailer;

/**
 * This class represents an envelope that can be sent to someone/some people.
 */
class Envelope {
  String from = 'hello@woven.co';
  List to;
  List bcc;
  String subject;
  String text;
  String html;

  Map toMap() {
    return {
        'from': from,
        'to': to,
        'bcc': bcc,
        'subject': subject,
        'html': html,
        'text': text
    };
  }
}
