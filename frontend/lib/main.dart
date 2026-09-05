import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as path_package;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

part 'src/app_core.dart';
part 'src/local_database.dart';
part 'src/auth.dart';
part 'src/shell.dart';
part 'src/dashboard.dart';
part 'src/events.dart';
part 'src/clients.dart';
part 'src/billing.dart';
part 'src/settings.dart';
part 'src/create_event.dart';
part 'src/event_details.dart';
part 'src/menu_master.dart';
part 'src/inventory.dart';
part 'src/employees_business_profile.dart';

void main() => runApp(const CaterProApp());
