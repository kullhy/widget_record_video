import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:widget_record_video/widget_record_video.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  final RecordingController recordingController = RecordingController();
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;
  Timer? _colorChangeTimer;
  Timer? _timer; // Timer for the countdown
  VideoPlayerController? _videoController;
  String? _videoPath;
  int elapsedTime = 0; // Time counter variable

  String? outputPath;

  @override
  void initState() {
    super.initState();
    _getOutPutPath();
    // Start color change timer for the animated container
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 3,
      ), // Set duration of the color change cycle
    )..repeat(); // Repeat animation infinitely

    // Create the color animation using a Tween
    _colorAnimation = ColorTween(
      begin: Colors.blue, // Starting color
      end: Colors.red, // Ending color
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _colorChangeTimer?.cancel();
    _timer?.cancel(); // Cancel the countdown timer
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _getOutPutPath() async {
    Directory? appDir = await getDownloadsDirectory();

    outputPath = '${appDir?.path}/result.mp4';
    setState(() {});
  }

  void _startRecording() {
    setState(() {
      elapsedTime = 0; // Reset the time counter
    });
    recordingController.start?.call();

    // Start the countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() {
        elapsedTime++;
      });
    });
  }

  Future<void> _stopRecording() async {
    recordingController.stop?.call();
    _timer?.cancel(); // Stop the countdown timer
  }

  void _pauseRecording() async {
    recordingController.pauseRecord?.call();
  }

  void _continueRecording() {
    recordingController.continueRecord?.call();
  }

  Future<void> _onRecordingComplete(String path) async {
    setState(() {
      _videoPath = path;
    });

    _videoController = VideoPlayerController.file(File(path))
      ..initialize().then((_) {
        setState(() {});
        _videoController!.play();
      });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Widget Record Example App')),
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 300.0,
                  child: RecordingWidget(
                    controller: recordingController,
                    onComplete: _onRecordingComplete,
                    outputPath: outputPath,
                    child: AnimatedBuilder(
                      animation: _colorAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 200,
                          height: 200,
                          color: _colorAnimation.value,
                          child: Center(
                            child: Text(
                              '$elapsedTime', // Display elapsed seconds
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _startRecording,
                      child: const Text('Start Recording'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _stopRecording,
                      child: const Text('Stop Recording'),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _pauseRecording,
                      child: const Text('Pause Recording'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _continueRecording,
                      child: const Text('Continue Recording'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_videoPath != null) ...[
                  const Text('Playback of Recorded Video:'),
                  const SizedBox(height: 10),
                  _videoController != null &&
                          _videoController!.value.isInitialized
                      ? Container(
                        width: 200,
                        height: 200,
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                      : const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
