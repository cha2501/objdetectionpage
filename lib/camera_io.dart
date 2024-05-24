import 'package:camera/camera.dart';

late List<CameraDescription> cameras;

Future<void> initCameras() async {
  cameras = await availableCameras();
}
