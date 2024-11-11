import 'dart:io';
// import 'package:gal/gal.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:how_to_recycle_this/env/env.dart';
import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({
    super.key
  });
  static const routeName = '/CameraPage';
  static const resultShowingTimeInSecs = 30;
  @override
  CameraPageState createState() => CameraPageState();
}

class CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isResultLoading = false;
  bool _visibleResult = false;
  String _result = "";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras!.isNotEmpty) {
      _controller = CameraController(_cameras![0], ResolutionPreset.low);
      _controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _isCameraInitialized = true;
        });
      });
    }
  }

  Future<void> takePictureAndAnalyze() async {
    if (!_controller!.value.isInitialized) {
      print("Controller is not initialized");
      return;
    }
    try {
      setState(() { 
        _isResultLoading = true;
      });

      final xfile = await _controller!.takePicture();
      final file = File(xfile.path);
      final bytes = await file.readAsBytes();
      // print("file bytes: $bytes");
      String base64Image = base64Encode(bytes);
    
      await analyzeImage(base64Image);

    } catch (e) {
      print("Error taking picture or converting to base64: $e");
    }
  }
  
  Future<void> analyzeImage(String imageBase64) async {
    
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${Env.GPT_API_KEY}'
    };
    var request = http.Request('POST', Uri.parse('${Env.GPT_API_URL}/chat/completions'));
    final payload = {
      "model": "gpt-4o-mini",
      "messages": [
        {
          "role": "user",
          "content": [
            {
              "type": "text",
              "text": "what is the object in the center of this image? Is it recycleable? How to recycle it? Consider the local regulation, and this is in British Columbia, Canada."
            },
            {
              "type": "image_url",
              "image_url": {
                "url": "data:image/jpeg;base64,$imageBase64"
              }
            }
          ],
          "max_tokens": 1000
        }
      ]
    };
    request.body = json.encode(payload);
    request.headers.addAll(headers);
    _result = '';
    
    final response = await request.send();
    if (response.statusCode == 200) {
      final r = await response.stream.bytesToString();
      final json = await jsonDecode(r);
      setState(() {
        _result = json["choices"][0]["message"]["content"];
        _isResultLoading = false;
        _visibleResult = true;
        Future.delayed(Duration(seconds: CameraPage.resultShowingTimeInSecs), () {
          setState(() {
            _visibleResult = false;
          });
        });
        // refresh UI
      });
      // print(_result);
    } else {
      setState(() {
        _isResultLoading = false;
        _visibleResult = false;
      });
      // print(Env.GPT_API_URL);
      // print(response.reasonPhrase);
    }
    
    // --- gpt ---
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // final operationAreaTopPadding = size.height - 300;
    return Scaffold(
      body: _isCameraInitialized && !_isResultLoading
          ? Stack(
              children: [
                SizedBox( // camera container
                  width: size.width,
                  height: size.height,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: 100,
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
                // Container( // action container
                  // child: 
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: size.height - 300,
                      ),
                      Container(
                        color: Colors.black.withOpacity(0.7),
                        height: 225,
                        child: Column(
                          children: [
                            Expanded(
                              flex: 1,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,//.horizontal
                                child: Visibility(
                                  visible: _visibleResult,
                                  child:  Text(_result,  
                                    style: const TextStyle(
                                      fontSize: 16.0, color: Colors.white70,
                                    ),
                                  ),
                                )
                              ),
                            ),
                          ]
                        )
                      ),
                      Container(
                        width: size.width,
                        height: 75,
                        color: Colors.black.withOpacity(0.7),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                children: [
                                  
                                ],
                              )
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: FloatingActionButton(
                                onPressed: takePictureAndAnalyze,
                                child: const Icon(Icons.camera),
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  )
                // ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}