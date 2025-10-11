import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
import 'package:record/record.dart';
import 'package:widget_record_video/src/recording_controller.dart';

class RecordingWidget extends StatefulWidget {
  const RecordingWidget({
    super.key,
    required this.child,
    required this.controller,
    this.limitTime = 120,
    required this.onComplete,
    this.outputPath,
    this.pixelRatio = 1,
    this.sampleRate = 48000,
    this.audioChannels = 1,
    this.audioBitrate = 64000,
    this.fps = 30,
  });

  /// This is the widget you want to record the screen
  final Widget child;

  /// [RecordingController] Used to start, pause, or stop screen recording
  final RecordingController controller;

  /// [limitTime] is the video recording time limit, when the limit is reached, the process automatically stops.
  /// Its default value is 120 seconds. If you do not have a limit, please set the value -1
  final int limitTime;

  /// [pixelRatio] The pixel ratio compared to the original widget. You should keep it at 1
  /// and only change it from 0.5 to 2 to ensure the best performance
  final double pixelRatio;

  final int sampleRate;
  final int audioChannels;
  final int audioBitrate;
  final int fps;

  /// [onComplete] is the next action after creating a video, it returns the video path
  final Function(String) onComplete;

  /// [outputPath] output address of the video, make sure you have write permission to this location otherwise leave it null, it will automatically be saved to app cache
  final String? outputPath;

  @override
  State<RecordingWidget> createState() => _RecordingWidgetState();
}

class _RecordingWidgetState extends State<RecordingWidget> {
  static const int audioChannels = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.start = startRecording;
    widget.controller.stop = stopRecording;
    widget.controller.pauseRecord = pauseRecording;
    widget.controller.continueRecord = continueRecording;
  }

  Directory? tempDir;

  Future<void> getImageSize() async {
    RenderRepaintBoundary boundary =
    recordKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: widget.pixelRatio);
    width = image.width;
    height = image.height;
  }

  GlobalKey recordKey = GlobalKey();
  int frameIndex = 0;
  bool isRecording = false;
  Timer? timer;
  int width = 0;
  int height = 0;

  bool isPauseRecord = false;

  BuildContext? _context;

  int elapsedTime = 0;
  Uint8List? audioFinal;

  void startRecording() {
    setState(() {
      isRecording = true;
      elapsedTime = 0;
    });
    startExportVideo();
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (elapsedTime >= widget.limitTime) {
        stopRecording();
      } else if (!isPauseRecord) {
        setState(() {
          elapsedTime++;
        });
      }
    });
  }

  Future stopRecording() async {
    timer?.cancel();
    setState(() {
      isRecording = false;
    });
  }

  void pauseRecording() {
    isPauseRecord = true;
  }

  void continueRecording() {
    isPauseRecord = false;
  }

  recordScreen() async {
    Future.delayed(Duration(milliseconds: 1000 ~/ widget.fps - 1 - (Random()).nextInt(2)), recordScreen);

    await _appendFrames(
        await captureWidgetAsRGBA(),
        null
    );
    frameIndex += 1;
  }

  Future<void> startExportVideo() async {
    Directory? appDir = await getApplicationCacheDirectory();

    try {
      int startTime = DateTime.now().millisecondsSinceEpoch;
      await getImageSize();

      await FlutterQuickVideoEncoder.setup(
        width: width,
        height: height,
        fps: widget.fps,
        videoBitrate: 1000000,
        profileLevel: ProfileLevel.any,
        audioBitrate: widget.audioBitrate,
        audioChannels: widget.audioChannels,
        sampleRate: widget.sampleRate,
        filepath: '${appDir.path}/exportVideoOnly.mp4',
      );

      Completer<void> readyForMore = Completer<void>();
      readyForMore.complete();

      final record = AudioRecorder();
      final stream = await record.startStream(RecordConfig(
          bitRate: widget.audioBitrate,
          encoder: AudioEncoder.pcm16bits,
          sampleRate: widget.sampleRate,
          numChannels: widget.audioChannels
      ));
      stream.listen((event) async {
        await FlutterQuickVideoEncoder.appendAudioFrame(event);
      });
      recordScreen();

      debugPrint("je suis la 36");

      while (isRecording) {
        if (!isPauseRecord) {
          await readyForMore.future;
          readyForMore = Completer<void>();

          Future.delayed(Duration(milliseconds: 100), readyForMore.complete);
        } else {
          await Future.delayed(const Duration(milliseconds: 20));
        }
      }

      await readyForMore.future;

      record.dispose();
      await FlutterQuickVideoEncoder.finish();
      int endTime = DateTime.now().millisecondsSinceEpoch;
      int videoTime = ((endTime - startTime) / 1000).round() - 1;
      debugPrint("video time: $videoTime");

      widget.onComplete(FlutterQuickVideoEncoder.filepath);
    } catch (e) {
      ('Error: $e');
    }
  }

  Future<Uint8List?> captureWidgetAsRGBA() async {
    try {
      RenderRepaintBoundary boundary =
      recordKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: widget.pixelRatio);
      width = image.width;
      height = image.height;

      ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint(
        e.toString(),
      );
      return null;
    }
  }

  Future<void> _appendFrames(
      Uint8List? videoFrame, Uint8List? audioFrame) async {
    if (videoFrame != null) {
      await FlutterQuickVideoEncoder.appendVideoFrame(videoFrame);
    } else {
      debugPrint("Error append video frame");
    }

    if (audioFrame != null) {
      await FlutterQuickVideoEncoder.appendAudioFrame(audioFrame);
    } else {
      debugPrint("Error append audio frame");
    }
  }

  void showSnackBar(String message) {
    debugPrint(message);
    final snackBar = SnackBar(content: Text(message));
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).showSnackBar(snackBar);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _context = context;
    return RepaintBoundary(
      key: recordKey,
      child: widget.child,
    );
  }
}
