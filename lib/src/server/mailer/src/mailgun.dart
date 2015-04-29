part of mailer;

class Mailgun {

  /**
   * Send a message.
   */
  static Future send(Envelope envelope) async {
    var user = config['mailgun']['user'];
    var key = config['mailgun']['key'];
    var path = config['mailgun']['path'];

    final auth = CryptoUtils.bytesToBase64(UTF8.encode("$user:$key"));
    final url = "${config['mailgun']['path']}/messages";

    http.Response response = await http.post(
        url,
        body: Envelope.prepareForPost(envelope),
        headers: {"authorization": "Basic $auth"}
    );

    Map responseAsMap = {};

    try {
      responseAsMap = JSON.decode(response.body);
    } catch (error) {
      responseAsMap = {'error': '$error'};
      print("Error in MailGun response:\n$error\nMailGun response was:\n${response.body}");
    }

    return {'status': response.statusCode, 'response': responseAsMap};
  }
}
