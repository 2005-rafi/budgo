import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:expense/provider/finance_boxes.dart';

class StorageInfoService {
  static String? _cachedDescription;
  static DateTime? _lastFetched;
  static const _ttl = Duration(minutes: 5);

  static void invalidate() {
    _cachedDescription = null;
    _lastFetched = null;
  }

  static Future<String> getBoxSizeDescription() async {
    final now = DateTime.now();
    if (_cachedDescription != null && _lastFetched != null && now.difference(_lastFetched!) < _ttl) {
      return _cachedDescription!;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final totalBytes = await compute(_calculateSizeInIsolate, dir.path);
      
      String description;
      if (totalBytes < 1024) {
        description = 'Database: ${totalBytes.toStringAsFixed(0)} B';
      } else if (totalBytes < 1024 * 1024) {
        final kb = totalBytes / 1024;
        description = 'Database: ${kb.toStringAsFixed(1)} KB';
      } else {
        final mb = totalBytes / (1024 * 1024);
        description = 'Database: ${mb.toStringAsFixed(1)} MB';
      }
      
      _cachedDescription = description;
      _lastFetched = now;
      return description;
    } catch (e) {
      return _cachedDescription ?? 'Database: Unknown size';
    }
  }
}

int _calculateSizeInIsolate(String dirPath) {
  final boxNames = FinanceBoxes.allBoxNames;
  int totalBytes = 0;
  for (var name in boxNames) {
    for (var ext in ['.hive', '.hivec']) {
      final file = File('$dirPath/$name$ext');
      if (file.existsSync()) {
        totalBytes += file.lengthSync();
      }
    }
  }
  return totalBytes;
}
