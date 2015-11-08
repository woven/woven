library mail_sender;

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'app.dart';
import 'firebase.dart';
import 'mailer/mailer.dart';
import 'package:woven/src/shared/response.dart';
import 'package:woven/config/config.dart';
import 'package:woven/src/shared/util.dart';
import 'package:woven/src/shared/regex.dart';

class MailSender {
  /**
   * Send a welcome email to the user when they complete sign up.
   */
  static sendWelcomeEmail(String username) async {
    username = username.toLowerCase();
    Map userData = await Firebase.get('/users/$username.json');

    // Customize the email based on whether the user is disabled or not.
    var emailText;
    if (userData['disabled']) {
      emailText = '''
<p>Access is limited at this time. The quickest way to get in is to <strong>ask a current participant to invite you</strong> to an existing channel. If you don't know someone, reply to this email and let us know which channel you believe you should have access to.</p>

<p>Otherwise, we'll let you know when we open up to more people and communities. Thank you very much for your patience.</p>
      ''';

    } else {
      emailText = '''
<p>Your username is <strong>${userData['username']}</strong>.</p>

<p>Please share your feedback and join us in shaping Woven at http://woven.co/woven.</p>

<p><strong>Pro tip:</strong> In any channel Lobby, use the <strong>/invite</strong> command followed by an email address to invite someone else. They will get immediate access. Oh, and try the <strong>/theme dark</strong> command.</p>
      ''';
    }

    // Send the welcome email.
    var envelope = new Envelope()
      ..from = "Woven <hello@woven.co>"
      ..to = ['${userData['firstName']} ${userData['lastName']} <${userData['email']}>']
      ..bcc = ['David Notik <davenotik@gmail.com>']
      ..subject = 'Welcome, ${userData['firstName']}!'
      ..html = '''
<p>Hi ${userData['firstName']},</p>

<p>Thank you for joining Woven.<p>

$emailText

<p>
--<br/>
Woven<br/>
<a href="http://woven.co">http://woven.co</a><br/>
<br/>
<a href="http://facebook.com/woven">http://facebook.com/woven</a><br/>
<a href="http://twitter.com/wovenco">http://twitter.com/wovenco</a><br/>
</p>
''';

    return Mailgun.send(envelope).then((success) {
      return new Response(success);
    });
  }

  /**
   * Send a welcome email to the user when they complete sign up.
   */
  static sendFixPasswordEmail(String username) async {
    username = username.toLowerCase();
    Map userData = await Firebase.get('/users/$username.json');

    // Customize the email based on whether the user is disabled or not.
    var emailText;
    if (userData['disabled']) {
      emailText = '''
<p>Access is limited at this time. The quickest way to get in is to <strong>ask a current participant to invite you</strong> to an existing channel. If you don't know someone, reply to this email and let us know which channel you believe you should have access to.</p>

<p>Otherwise, we'll let you know when we open up to more people and communities. Thank you very much for your patience.</p>
      ''';

    } else {
      emailText = '''
<p>Your username is <strong>${userData['username']}</strong>.</p>

<p>Please share your feedback and join us in shaping Woven at http://woven.co/woven.</p>

<p><strong>Pro tip:</strong> In any channel Lobby, use the <strong>/invite</strong> command followed by an email address to invite someone else. They will get immediate access.</p>
      ''';
    }

    // Send the welcome email.
    var envelope = new Envelope()
      ..from = "Woven <hello@woven.co>"
      ..to = ['${userData['firstName']} ${userData['lastName']} <${userData['email']}>']
      ..bcc = ['David Notik <davenotik@gmail.com>']
      ..subject = '${userData['firstName']}, please re-create your account'
      ..html = '''
<p>Hi ${userData['firstName']},</p>

<p>You signed up recently, but we had a bug that meant your chosen password wasn't saved. Easiest is if you'd please sign up again.<p>

<p>Go to <a href="http://woven.co">http://woven.co</a> and enter your email, confirm your email, and create your account. Choose the same username as before (<strong>${userData['username']}</strong>).</p>

<p>Then reply to this email to let me know, and I'll approve your account.</p>

<p>Sorry for the trouble,</p>

<p>David Notik</p>

<p>
--<br/>
Woven<br/>
<a href="http://woven.co">http://woven.co</a><br/>
<br/>
<a href="http://facebook.com/woven">http://facebook.com/woven</a><br/>
<a href="http://twitter.com/wovenco">http://twitter.com/wovenco</a><br/>
</p>
''';

    return Mailgun.send(envelope).then((success) {
      print (success);
      return new Response(success);
    });
  }
}