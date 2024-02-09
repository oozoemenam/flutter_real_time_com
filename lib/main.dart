import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo WebRTC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter WebRTC'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _offer = false;
  late RTCPeerConnection _peerConnection;
  late MediaStream _localStream;

  final sdpController = TextEditingController();

  void initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<MediaStream> _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': false,
      'video': {
        'facingMode': 'user',
      },
    };
    MediaStream stream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = stream;
    // _localRenderer.mirror = true;
    return stream;
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
      ]
    };
    final Map<String, dynamic> offerSdpConstraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };
    _localStream = await _getUserMedia();
    RTCPeerConnection pc =
        await createPeerConnection(configuration, offerSdpConstraints);
    pc.addStream(_localStream);
    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMLineIndex,
        }));
      }
    };
    pc.onIceConnectionState = (e) {
      print(e);
    };
    pc.onAddStream = (stream) {
      print('addStream: ${stream.id}');
      _remoteRenderer.srcObject = stream;
    };
    return pc;
  }

  void _createOffer() async {
    RTCSessionDescription description =
        await _peerConnection.createOffer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp!);
    print(json.encode(session));
    _offer = true;
    _peerConnection.setLocalDescription(description);
  }

  void _createAnswer() async {
    RTCSessionDescription description =
        await _peerConnection.createAnswer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp!);
    print(json.encode(session));
    _peerConnection.setLocalDescription(description);
  }

  void _setRemoteDescription() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode(jsonString);
    String sdp = write(session, null);
    RTCSessionDescription description =
        RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print(description.toMap());
    await _peerConnection.setRemoteDescription(description);
  }

  void _setCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode(jsonString);
    print(session['candidate']);
    final candidate = RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection.addCandidate(candidate);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    initRenderers();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          videoRenderers(),
          offerAndAnswerButtons(),
          sdpCandidateTF(),
          sdpCandidateButtons(),
        ],
      ),
    );
  }

  SizedBox videoRenderers() {
    return SizedBox(
      height: 210,
      child: Row(
        children: [
          Flexible(
            child: Container(
              key: const Key('local'),
              margin: const EdgeInsets.fromLTRB(5, 5, 5, 5),
              decoration: const BoxDecoration(color: Colors.black),
              child: RTCVideoView(_localRenderer),
            ),
          ),
          Flexible(
            child: Container(
              key: const Key('remote'),
              margin: const EdgeInsets.fromLTRB(5, 5, 5, 5),
              decoration: const BoxDecoration(color: Colors.black),
              child: RTCVideoView(_remoteRenderer),
            ),
          ),
        ],
      ),
    );
  }

  Row offerAndAnswerButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: _createOffer,
          child: const Text('Offer'),
        ),
        ElevatedButton(
          onPressed: _createAnswer,
          child: const Text('Answer'),
        ),
      ],
    );
  }

  Padding sdpCandidateTF() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: sdpController,
        keyboardType: TextInputType.multiline,
        maxLines: 4,
        maxLength: TextField.noMaxLength,
      ),
    );
  }

  Row sdpCandidateButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton(
          onPressed: _setRemoteDescription,
          child: const Text('Set Remote Desc'),
        ),
        ElevatedButton(
          onPressed: _setCandidate,
          child: const Text('Set Candidate'),
        ),
      ],
    );
  }
}
