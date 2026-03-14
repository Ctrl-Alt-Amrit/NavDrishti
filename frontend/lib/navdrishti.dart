import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

late List<CameraDescription> cameras;

class NavDrishti extends StatelessWidget {
  const NavDrishti({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  late CameraController controller;
  int cameraIndex = 0;

  final FlutterTts flutterTts = FlutterTts();

  Future sendImageToBackend(File imageFile) async {

    var request = http.MultipartRequest(
      'POST',
      Uri.parse("http://172.20.10.2:8000/detect"),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ),
    );

    var response = await request.send();

    if (response.statusCode == 200) {

      var responseData = await response.stream.bytesToString();

      var jsonData = jsonDecode(responseData);

      var objects = jsonData["objects"];

      print(jsonData);

      if(objects.isNotEmpty){
        await flutterTts.speak(objects.join(", "));
      }

    } else {

      print("Backend error");

    }
  }

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {

    cameras = await availableCameras();

    controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.high,
    );

    await controller.initialize();

    if (!mounted) return;
    setState(() {});
  }

  /// MICROPHONE FEEDBACK
  Future<void> micFeedback() async {

    XFile image = await controller.takePicture();
    sendImageToBackend(File(image.path));

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 150);
    }

    await flutterTts.speak("Microphone");
  }

  /// CAMERA SWITCH
  Future<void> switchCamera() async {

    cameraIndex = cameraIndex == 0 ? 1 : 0;

    await controller.dispose();

    controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.high,
    );

    await controller.initialize();

    setState(() {});

    /// VIBRATION
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 150);
    }

    /// SPEECH
    if (cameraIndex == 0) {
      await flutterTts.speak("Camera flipped to rear camera");
    } else {
      await flutterTts.speak("Camera flipped to front camera");
    }
  }

  @override
  void dispose() {
    controller.dispose();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B16),

      body: Column(
        children: [

          const SizedBox(height: 40),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "NavDrishti",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.settings),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipPath(
                clipper: CameraArchClipper(),
                child: controller.value.isInitialized
                    ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize!.height,
                    height: controller.value.previewSize!.width,
                    child: CameraPreview(controller),
                  ),
                )
                    : const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 2),

          Transform.translate(
            offset: const Offset(0, -25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [

                /// LEFT BUTTON
                Transform.translate(
                  offset: const Offset(0, 8),
                  child: const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.history, color: Colors.black),
                  ),
                ),

                /// MIC BUTTON
                GestureDetector(
                  onTap: micFeedback,
                  child: const CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.mic, size: 50),
                  ),
                ),

                /// RIGHT BUTTON
                Transform.translate(
                  offset: const Offset(0, 8),
                  child: GestureDetector(
                    onTap: switchCamera,
                    child: const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.flip_camera_android),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class CameraArchClipper extends CustomClipper<Path> {

  @override
  Path getClip(Size size) {

    double archWidth = 130;
    double archHeight = 75;

    double center = size.width / 2;

    Path path = Path();

    path.moveTo(0, 0);

    path.lineTo(0, size.height);

    path.lineTo(center - archWidth/2, size.height);

    path.quadraticBezierTo(
      center,
      size.height - archHeight,
      center + archWidth/2,
      size.height,
    );

    path.lineTo(size.width, size.height);

    path.lineTo(size.width, 0);

    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}