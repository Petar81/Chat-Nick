import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Nik',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Chat Nik'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _localRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    initRenderers();
    _getUserMedia();
  }

  @override
  void dispose() {
    super.dispose();
    _localRenderer.dispose();
  }

  initRenderers() async {
    await _localRenderer.initialize();
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      "audio": false,
      "video": {'facingMode': 'user'}
    };
    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = stream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: SizedBox(
          child: Stack(
            children: <Widget>[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  child: RTCVideoView(_localRenderer),
                ),
              )
            ],
          ),
        ));
  }
}
