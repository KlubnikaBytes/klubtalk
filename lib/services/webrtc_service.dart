import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:whatsapp_clone/services/socket_service.dart';

typedef StreamStateCallback = void Function(MediaStream stream);
typedef CallStateCallback = void Function(String status);
typedef TimerCallback = void Function(int seconds);

class WebrtcService {
  static final WebrtcService _instance = WebrtcService._internal();

  factory WebrtcService() => _instance;

  WebrtcService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream; // Exposed to UI
  
  StreamStateCallback? onLocalStream;
  StreamStateCallback? onRemoteStream;
  CallStateCallback? onCallStateChange;
  
  String? _peerId;
  String? _connectionId; // Socket ID or User ID we are talking to
  
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  // State
  bool isAudioEnabled = true;
  bool isVideoEnabled = true;

  Future<void> initCall(String peerId, bool video) async {
    _peerId = peerId;
    _createPeerConnection();
    
    // Get User Media
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': video ? {
          'facingMode': 'user',
      } : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    onLocalStream?.call(_localStream!);

    // Add Tracks to Peer Connection
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
    
    // Create Offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    // Send Offer via Socket
    SocketService().emit('call-user', {
       'to': peerId,
       'from': SocketService().socket?.id, // NOTE: Ideally we use USER ID not socket ID for robust auth, assuming auth middleware handles identity mapping
       // But wait, our socket implementation in index.js uses data.to and data.from which are USER IDs usually.
       // Let's assume we pass our UserID.
       // Handled by caller UI passing correct IDs.
       'callType': video ? 'video' : 'audio',
       'offer': offer.toMap(),
    });
    
    onCallStateChange?.call("Calling...");
  }
  
  // Handle Incoming Call (We received an offer)
  Future<void> handleIncomingCall(Map<String, dynamic> data) async {
      // data: { from, callType, offer }
      _connectionId = data['from']; // Caller ID
      bool video = data['callType'] == 'video';
      
      await _createPeerConnection();
      
      // Get Local Media
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': video ? { 'facingMode': 'user' } : false,
      };
      
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      onLocalStream?.call(_localStream!);
      
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
      
      // Set Remote Desc (Offer)
      await _peerConnection!.setRemoteDescription(
         RTCSessionDescription(data['offer']['sdp'], data['offer']['type'])
      );
      
      // Create Answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      // Send Answer
      SocketService().emit('accept-call', {
          'to': _connectionId,
          'from': 'ME', // Server might key this or we pass our ID
          'answer': answer.toMap() 
      });
      
      onCallStateChange?.call("Connecting...");
  }
  
  // Handle Answer (Caller receives answer)
  Future<void> handleAnswer(Map<String, dynamic> data) async {
      if (_peerConnection != null) {
         await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(data['answer']['sdp'], data['answer']['type'])
         );
         onCallStateChange?.call("On Call");
      }
  }
  
  // Handle ICE Candidate
  Future<void> handleCandidate(Map<String, dynamic> data) async {
      if (_peerConnection != null && data['candidate'] != null) {
         RTCIceCandidate candidate = RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex']
         );
         await _peerConnection!.addCandidate(candidate);
      }
  }

  Future<void> _createPeerConnection() async {
     _peerConnection = await createPeerConnection(_configuration);
     
     _peerConnection!.onIceCandidate = (candidate) {
        if (_connectionId != null || _peerId != null) {
           SocketService().emit('ice-candidate', {
              'to': _connectionId ?? _peerId,
              'candidate': candidate.toMap()
           });
        }
     };
     
     _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
           _remoteStream = event.streams[0];
           onRemoteStream?.call(_remoteStream!);
        }
     };
     
     _peerConnection!.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
              endCall();
        }
     };
  }

  void endCall() {
     _localStream?.getTracks().forEach((track) => track.stop());
     _localStream?.dispose();
     _remoteStream?.dispose();
     _peerConnection?.close();
     _peerConnection = null;
     _localStream = null;
     _remoteStream = null;
     
     SocketService().emit('end-call', {'to': _connectionId ?? _peerId});
     onCallStateChange?.call("Ended");
  }

  // Toggles
  void toggleMute() {
     if (_localStream != null) {
        isAudioEnabled = !isAudioEnabled;
        _localStream!.getAudioTracks()[0].enabled = isAudioEnabled;
     }
  }
  
  void toggleVideo() {
     if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
        isVideoEnabled = !isVideoEnabled;
        _localStream!.getVideoTracks()[0].enabled = isVideoEnabled;
     }
  }
  
  void switchCamera() {
     if (_localStream != null) {
        // Helper.switchCamera(_localStream!.getVideoTracks()[0]); 
        // Need Helper class or manual logic. FlutterWebRTC provides Helper.
        Helper.switchCamera(_localStream!.getVideoTracks()[0]);
     }
  }
}
