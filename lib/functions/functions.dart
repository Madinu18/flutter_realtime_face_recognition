import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_real_time_face_recognition/utils/utils.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

part 'database_helper.dart';
part 'ml_service.dart';
part 'camera_helper.dart';