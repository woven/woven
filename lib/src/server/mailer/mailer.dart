library mailer;

import '../../../config/config.dart';

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

//import 'package:path/path.dart';
//import 'package:mime/mime.dart';
import 'package:crypto/crypto.dart';

part 'src/envelope.dart';
part 'src/mailgun.dart';
part 'src/util.dart';