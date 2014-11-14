part of mailer;

class Mailgun {

  /**
   * Send a message.
   */
  Future send(Envelope envelope) {
    var user = config['mailgun']['user'];
    var key = config['mailgun']['key'];
    var path = config['mailgun']['path'];

    final auth = CryptoUtils.bytesToBase64(UTF8.encode("$user:$key"));
    final url = "${config['mailgun']['path']}/messages";
    return http.post(url, body: envelope.toMap(), headers: {"authorization": "Basic $auth"})
    .then((response) {
      print("Mailgun response: ${response.body}");
      Map responseAsMap = JSON.decode(response.body);
      return {'status': response.statusCode, 'response': responseAsMap};
//      if (response.statusCode == 400) {
//        throw 'Mailgun returned an error.\nPath: $url\nData: ${envelope.toMap()}\nResponse: ${responseAsMap["message"]}';
//      }
//      if (response.statusCode == 200) {
//        return responseAsMap['message'];
//      }
    });
  }
}
