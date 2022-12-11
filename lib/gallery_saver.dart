import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:gallery_saver/files.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class GallerySaver {
  static const String channelName = 'gallery_saver';
  static const String methodSaveImage = 'saveImage';
  static const String methodSaveVideo = 'saveVideo';

  static const String pleaseProvidePath = 'Please provide valid file path.';
  static const String fileIsNotVideo = 'File on path is not a video.';
  static const String fileIsNotImage = 'File on path is not an image.';
  static const MethodChannel _channel = const MethodChannel(channelName);

  ///saves video from provided temp path and optional album name in gallery
  static Future<bool?> saveVideo(String path,
      {String? albumName,
      bool toDcim = false,
      Map<String, String>? headers,
      Function(int received, int total)? onReceiveProgress}) async {
    File? tempFile;
    if (path.isEmpty) {
      throw ArgumentError(pleaseProvidePath);
    }
    if (!isVideo(path)) {
      throw ArgumentError(fileIsNotVideo);
    }
    if (!isLocalFilePath(path)) {
      tempFile = await _downloadFile(path, onReceiveProgress, headers: headers);
      path = tempFile.path;
    }
    bool? result = await _channel.invokeMethod(
      methodSaveVideo,
      <String, dynamic>{'path': path, 'albumName': albumName, 'toDcim': toDcim},
    );
    if (tempFile != null) {
      tempFile.delete();
    }
    return result;
  }

  ///saves image from provided temp path and optional album name in gallery
  static Future<bool?> saveImage(String path,
      {String? albumName,
      bool toDcim = false,
      Map<String, String>? headers,
      Function(int, int)? onReceiveProgress}) async {
    File? tempFile;
    if (path.isEmpty) {
      throw ArgumentError(pleaseProvidePath);
    }
    if (!isImage(path)) {
      throw ArgumentError(fileIsNotImage);
    }
    if (!isLocalFilePath(path)) {
      tempFile = await _downloadFile(path, onReceiveProgress, headers: headers);
      path = tempFile.path;
    }

    bool? result = await _channel.invokeMethod(
      methodSaveImage,
      <String, dynamic>{'path': path, 'albumName': albumName, 'toDcim': toDcim},
    );
    if (tempFile != null) {
      tempFile.delete();
    }

    return result;
  }

  static Future<File> _downloadFile(
      String url, Function(int, int)? onReceiveProgress,
      {Map<String, String>? headers}) async {
    print(url);
    print(headers);
    http.Client _client = new http.Client();
    // var req = await _client.get(Uri.parse(url), headers: headers);
    var req = await _client.send(http.Request('GET', Uri.parse(url)));
    int total = req.contentLength ?? 0;
    int received = 0;
    final List<int> bytes = [];

    if (req.statusCode >= 400) {
      throw HttpException(req.statusCode.toString());
    }

    try {
      await for (final value in req.stream) {
        bytes.addAll(value);
        received += value.length;
        onReceiveProgress!(received, total);
      }
    } catch (e) {
      throw ArgumentError(fileIsNotVideo);
    }

    String dir = (await getTemporaryDirectory()).path;
    File file = new File('$dir/${basename(url)}');

    await file.writeAsBytes(bytes);

    print('File size:${await file.length()}');
    print(file.path);

    return file;
  }
}
