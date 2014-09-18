part of mailer;

/**
 * This class represents an envelope that can be sent to someone/some people.
 */
class Envelope {
  String from = 'anonymous@woven.co';
  String to;
  String bcc;
  String subject;
  String text;

  Future<Map> toMap() {
    return {
        'from': from,
        'to': to,
        'bcc': bcc,
        'subject': subject,
        'text': text
    };
  }
}
