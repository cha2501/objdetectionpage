import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'camera_stub.dart' if (dart.library.io) 'camera_io.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_vision/flutter_vision.dart';

// Global variable for cameras
late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    cameras = await availableCameras();
  }
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MegaView',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurpleAccent),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const YoloVideo(),
    );
  }
}

class YoloVideo extends StatefulWidget {
  const YoloVideo({super.key});

  @override
  State<YoloVideo> createState() => _YoloVideoState();
}

class _YoloVideoState extends State<YoloVideo> {
  late CameraController controller;
  late List<Map<String, dynamic>> yoloResults;
  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;

  late FlutterVision vision;
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      vision = FlutterVision();
      initTTS();
      init();
    }
  }

  Future<void> initTTS() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(1.0);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    await flutterTts.speak(text);
  }

  init() async {
    controller = CameraController(cameras[0], ResolutionPreset.max, enableAudio: false);
    await controller.initialize();
    await loadYoloModel();
    setState(() {
      isLoaded = true;
      isDetecting = false;
      yoloResults = [];
    });
  }

  @override
  void dispose() {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      flutterTts.stop();
      vision.closeYoloModel();
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Scaffold(
        body: Center(child: Text("Model not loaded. Waiting for it.")),
      );
    }
    return !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)
        ? Stack(
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
              ),
              ...displayBoxesAroundRecognizedObjects(MediaQuery.of(context).size),
              Positioned(
                bottom: 75,
                width: MediaQuery.of(context).size.width,
                child: Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(width: 5, color: Colors.white),
                  ),
                  child: isDetecting
                      ? IconButton(
                          onPressed: stopDetection,
                          icon: const Icon(Icons.stop, color: Colors.red),
                          iconSize: 50,
                        )
                      : IconButton(
                          onPressed: startDetection,
                          icon: const Icon(Icons.play_arrow, color: Colors.white),
                          iconSize: 50,
                        ),
                ),
              ),
            ],
          )
        : const Scaffold(
            body: Center(child: Text("This feature is not available on this platform.")),
          );
  }


   Future<void> loadYoloModel() async {
    try {
      print("Loading YOLO model...");
      await vision.loadYoloModel(
          labels: 'assets/labels.txt',
          modelPath: 'assets/yolov5n.tflite',
          modelVersion: "yolov5",
          numThreads: 1,
          useGpu: false);  // Set useGpu to false
      print("YOLO model loaded successfully.");
      setState(() {
        isLoaded = true;
      });
    } catch (e) {
      print("Failed to load YOLO model: $e");
    }
  }


  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    final result = await vision.yoloOnFrame(
        bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
        imageHeight: cameraImage.height,
        imageWidth: cameraImage.width,
        iouThreshold: 0.4,
        confThreshold: 0.4,
        classThreshold: 0.5);
    if (result.isNotEmpty) {
      setState(() {
        yoloResults = result;
      });
    }
  }

  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
    });
    if (!controller.value.isStreamingImages) {
      await controller.startImageStream((image) async {
        if (isDetecting) {
          cameraImage = image;
          yoloOnFrame(image);
        }
      });
    }
  }

  Future<void> stopDetection() async {
    setState(() {
      isDetecting = false;
      yoloResults.clear();
    });
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];
    double factorX = screen.width / (cameraImage?.height ?? 1);
    double factorY = screen.height / (cameraImage?.width ?? 1);
    return yoloResults.map((result) {
      speak("${result['tag']}");
      return Positioned(
        left: result["box"][0] * factorX,
        top: result["box"][1] * factorY,
        width: (result["box"][2] - result["box"][0]) * factorX,
        height: (result["box"][3] - result["box"][1]) * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(10.0)),
            border: Border.all(color: Colors.pink, width: 2.0),
          ),
          child: Text(
            "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = Colors.green,
              color: Colors.white,
              fontSize: 18.0,
            ),
          ),
        ),
      );
    }).toList();
  }
}
