import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CameraPage extends StatefulWidget {
  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  String _message = "Đang khởi tạo camera...";
  bool _isRecording = false;
  bool _isFlashOn = false;
  int _selectedCameraIdx = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    var status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        _cameras = await availableCameras();
        if (_cameras != null && _cameras!.isNotEmpty) {
          _controller = CameraController(
            _cameras![_selectedCameraIdx],
            ResolutionPreset.high,
            enableAudio: true, // Bật audio cho quay video
          );
          await _controller!.initialize();
          setState(() {
            _isCameraInitialized = true;
            _message = "Camera đã sẵn sàng!";
          });
        } else {
          setState(() {
            _message = "Không tìm thấy camera nào.";
          });
        }
      } catch (e) {
        setState(() {
          _message = "Lỗi khởi tạo camera: $e";
        });
        print("Camera initialization error: $e");
      }
    } else {
      setState(() {
        _message = "Quyền truy cập camera bị từ chối.";
      });
      print("Camera permission denied.");
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() {
      _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras!.length;
      _isCameraInitialized = false;
      _isRecording = false;
      _isFlashOn = false;
    });

    await _controller?.dispose();
    await _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      print("Error toggling flash: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể bật/tắt flash: $e")),
      );
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile file = await _controller!.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final String filePath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await file.saveTo(filePath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã chụp ảnh và lưu vào: $filePath")),
      );
      print("Picture saved to: $filePath");
    } catch (e) {
      print("Error taking picture: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể chụp ảnh: $e")),
      );
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isRecording) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đang quay video...")),
      );
    } catch (e) {
      print("Error starting video recording: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể bắt đầu quay video: $e")),
      );
    }
  }

  Future<void> _stopVideoRecording() async {
    if (!_isRecording) return;

    try {
      final XFile file = await _controller!.stopVideoRecording();
      final directory = await getApplicationDocumentsDirectory();
      final String filePath = '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';
      await file.saveTo(filePath);
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã quay video và lưu vào: $filePath")),
      );
      print("Video saved to: $filePath");
    } catch (e) {
      print("Error stopping video recording: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể dừng quay video: $e")),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCameraInitialized && _controller != null && _controller!.value.isInitialized) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: CameraPreview(_controller!),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 40.0, right: 10.0),
                child: Column(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: _toggleFlash,
                    ),
                    SizedBox(height: 10),
                    IconButton(
                      icon: Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: _toggleCamera,
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: GestureDetector(
                  onTap: _takePicture,
                  onLongPressStart: (_) => _startVideoRecording(),
                  onLongPressEnd: (_) => _stopVideoRecording(),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                    child: Center(
                      child: _isRecording
                          ? Icon(Icons.fiber_manual_record, color: Colors.red, size: 40)
                          : Icon(Icons.camera, color: Color(0xFF075E54), size: 40),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_alt,
                size: 100,
                color: Colors.white,
              ),
              SizedBox(height: 20),
              Text(
                "Camera",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
