import 'dart:developer';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

class Ultis {
  static Future<double> _getVideoDuration(String filepath) async {
    double originalDuration = 0;
    final data = await FFprobeKit.getMediaInformation(filepath);
    final media = data.getMediaInformation();
    final secondsStr = media?.getDuration();
    originalDuration = double.parse(secondsStr ?? "0");
    return originalDuration;
  }

  static Future<double> _calculateSpeedRatio(
      String filepath, int targetDuration) async {
    double originalDuration = await _getVideoDuration(filepath);
    if (originalDuration == 0.0) {
      return 1.0;
    }
    return targetDuration / originalDuration;
  }

  // adjust Video Speed
  static Future<String> adjustVideoSpeed(
      String filepath, int targetDuration, String? outputPath) async {
    final speedRatio = await _calculateSpeedRatio(filepath, targetDuration);
    Directory? appDir = await getApplicationCacheDirectory();

    outputPath ??= '${appDir.path}/result.mp4';
    final command =
        '-y -i $filepath -filter:v "setpts=$speedRatio*PTS" $outputPath';

    final result = await FFmpegKit.execute(command);
    final returnCode = await result.getReturnCode();

    var message = await result.getAllLogs();
    for (var mes in message) {
      log(mes.getMessage());
    }

    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    } else {
      return "";
    }
  }
}
