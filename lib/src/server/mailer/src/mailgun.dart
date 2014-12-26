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
    return http.post(url, body: prepareEnvelopeForPost(envelope), headers: {"authorization": "Basic $auth"})
    .then((response) {
      Map responseAsMap = {};
      try {
        responseAsMap = JSON.decode(response.body);
      } catch(error) {
        responseAsMap = {'error': '$error'};
        print("Error in MailGun response:\n$error\nMailGun response was:\n${response.body}");
      }

      return {'status': response.statusCode, 'response': responseAsMap};
//      if (response.statusCode == 400) {
//        throw 'Mailgun returned an error.\nPath: $url\nData: ${envelope.toMap()}\nResponse: ${responseAsMap["message"]}';
//      }
//      if (response.statusCode == 200) {
//        return responseAsMap['message'];
//      }
    });
  }

  /**
   * Prepare the envelope for transmission over http POST.
   *
   * Removes null properties and converts lists to strings.
   */
  prepareEnvelopeForPost(Envelope e) {
    Map map = e.toMap();
    Map newMap = new Map.from(map);
    map.forEach((k, v) {
      if (v is List) newMap[k] = (v as List).join(',');
    });
    return removeNullsFromMap(newMap);
  }
}
