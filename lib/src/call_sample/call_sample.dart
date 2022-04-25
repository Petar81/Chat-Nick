import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:core';
import 'signaling.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audioplayers/audioplayers.dart';

class CallSample extends StatefulWidget {
  static String tag = 'call_sample';
  final String host;
  CallSample({required this.host});

  @override
  _CallSampleState createState() => _CallSampleState();
}

class _CallSampleState extends State<CallSample> {
  Signaling? _signaling;
  List<dynamic> _peers = [];
  String? _selfId;
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCalling = false;
  Session? _session;

  final AudioCache _audioCache = AudioCache(
    prefix: 'audio/',
    fixedPlayer: AudioPlayer()..setReleaseMode(ReleaseMode.STOP),
  );

  bool _waitAccept = false;

  // ignore: unused_element
  _CallSampleState();

  @override
  initState() {
    super.initState();
    initRenderers();
    _connect();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  deactivate() {
    super.deactivate();
    _signaling?.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  void _connect() async {
    _signaling ??= Signaling(widget.host)..connect();
    _signaling?.onSignalingStateChange = (SignalingState state) {
      switch (state) {
        case SignalingState.ConnectionClosed:
        case SignalingState.ConnectionError:
        case SignalingState.ConnectionOpen:
          break;
      }
    };

    _signaling?.onCallStateChange = (Session session, CallState state) async {
      switch (state) {
        case CallState.CallStateNew:
          setState(() {
            _session = session;
          });
          break;
        case CallState.CallStateRinging:
          bool? accept = await _showAcceptDialog();
          if (accept!) {
            _accept();
            setState(() {
              _inCalling = true;
            });
          } else {
            _reject();
          }
          break;
        case CallState.CallStateBye:
          if (_waitAccept) {
            print('peer reject');
            _waitAccept = false;
            Navigator.of(context).pop(false);
          }
          setState(() {
            _localRenderer.srcObject = null;
            _remoteRenderer.srcObject = null;
            _inCalling = false;
            _session = null;
          });
          break;
        case CallState.CallStateInvite:
          _waitAccept = true;
          _showInvateDialog();
          break;
        case CallState.CallStateConnected:
          if (_waitAccept) {
            _waitAccept = false;
            Navigator.of(context).pop(false);
          }
          setState(() {
            _inCalling = true;
          });

          break;
        case CallState.CallStateRinging:
      }
    };

    _signaling?.onPeersUpdate = ((event) {
      setState(() {
        _selfId = event['self'];
        _peers = event['peers'];
      });
    });

    _signaling?.onLocalStream = ((stream) {
      _localRenderer.srcObject = stream;
    });

    _signaling?.onAddRemoteStream = ((_, stream) {
      _remoteRenderer.srcObject = stream;
    });

    _signaling?.onRemoveRemoteStream = ((_, stream) {
      _remoteRenderer.srcObject = null;
    });
  }

  Future<bool?> _showAcceptDialog() {
    _audioCache.play('black_sheriff.mp3');
    return showDialog<bool?>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text("Incoming call"),
          content: const Image(image: AssetImage('assets/incoming_call.gif')),
          actions: <Widget>[
            Container(
              decoration: BoxDecoration(color: Colors.red),
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: TextButton.icon(
                  icon: Icon(Icons.phone_disabled_sharp, color: Colors.white),
                  label: Text(
                    "reject",
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    await _audioCache.fixedPlayer!.stop();
                    Navigator.of(context).pop(false);
                  }),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.green),
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: TextButton.icon(
                icon: Icon(Icons.call_rounded, color: Colors.white),
                label: Text(
                  "accept",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  await _audioCache.fixedPlayer!.stop();
                  Navigator.of(context).pop(true);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showInvateDialog() {
    return showDialog<bool?>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text("Outgoing call"),
          content: const Image(image: AssetImage('assets/outgoing_call.gif')),
          actions: <Widget>[
            Container(
              decoration: BoxDecoration(color: Colors.red),
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: TextButton.icon(
                icon: Icon(Icons.phone_disabled_sharp, color: Colors.white),
                label: Text(
                  "cancel",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  Navigator.of(context).pop(false);
                  _hangUp();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  _invitePeer(BuildContext context, String peerId, bool useScreen) async {
    if (_signaling != null && peerId != _selfId) {
      _signaling?.invite(peerId, 'video', useScreen);
    }
  }

  _accept() {
    if (_session != null) {
      _signaling?.accept(_session!.sid);
    }
  }

  _reject() {
    if (_session != null) {
      _signaling?.reject(_session!.sid);
    }
  }

  _hangUp() {
    if (_session != null) {
      _signaling?.bye(_session!.sid);
    }
  }

  _switchCamera() {
    _signaling?.switchCamera();
  }

  _muteMic() {
    _signaling?.muteMic();
  }

  _buildRow(context, peer) {
    var self = (peer['id'] == _selfId);
    return ListBody(children: <Widget>[
      ListTile(
        title: Text(self
            ? peer['name'] + ', ID: ${peer['id']} ' + ' [Your self]'
            : peer['name'] + ', ID: ${peer['id']} '),
        onTap: null,
        trailing: SizedBox(
            width: 100.0,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                    icon: Icon(self ? Icons.close : Icons.videocam,
                        color: self ? Colors.grey : Colors.black),
                    onPressed: () => _invitePeer(context, peer['id'], false),
                    tooltip: 'Video calling',
                  ),
                  IconButton(
                    icon: Icon(self ? Icons.close : Icons.screen_share,
                        color: self ? Colors.grey : Colors.black),
                    onPressed: () => _invitePeer(context, peer['id'], true),
                    tooltip: 'Screen sharing',
                  )
                ])),
        subtitle: Text('[' + peer['user_agent'] + ']'),
      ),
      Divider()
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selfId != null ? ' [Your ID ($_selfId)] ' : ''),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: null,
            tooltip: 'setup',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _inCalling
          ? SizedBox(
              width: 200.0,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    FloatingActionButton(
                      child: const Icon(Icons.switch_camera),
                      onPressed: _switchCamera,
                      tooltip: 'Switch Camera',
                    ),
                    FloatingActionButton(
                      onPressed: _hangUp,
                      tooltip: 'Hangup',
                      child: Icon(Icons.call_end),
                      backgroundColor: Colors.pink,
                    ),
                    FloatingActionButton(
                      child: const Icon(Icons.mic_off),
                      onPressed: _muteMic,
                      tooltip: 'Mute Mic',
                    )
                  ]))
          : null,
      body: _inCalling
          ? OrientationBuilder(builder: (context, orientation) {
              return Container(
                child: Stack(children: <Widget>[
                  Positioned(
                      left: 0.0,
                      right: 0.0,
                      top: 0.0,
                      bottom: 0.0,
                      child: Container(
                        margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child: RTCVideoView(_remoteRenderer),
                        decoration: BoxDecoration(color: Colors.black54),
                      )),
                  Positioned(
                    left: 20.0,
                    top: 20.0,
                    child: Container(
                      width: orientation == Orientation.portrait ? 90.0 : 120.0,
                      height:
                          orientation == Orientation.portrait ? 120.0 : 90.0,
                      child: RTCVideoView(_localRenderer, mirror: true),
                      decoration: BoxDecoration(color: Colors.black54),
                    ),
                  ),
                ]),
              );
            })
          : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(0.0),
              itemCount: (_peers != null ? _peers.length : 0),
              itemBuilder: (context, i) {
                return _buildRow(context, _peers[i]);
              }),
    );
  }
}
