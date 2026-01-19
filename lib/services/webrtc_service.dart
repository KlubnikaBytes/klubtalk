import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/services/socket_service.dart';

typedef StreamStateCallback = void Function(MediaStream stream);
typedef CallStateCallback = void Function(String status);
typedef TimerCallback = void Function(int seconds);

class WebrtcService {
  static final WebrtcService _instance = WebrtcService._internal();

  factory WebrtcService() => _instance;

  WebrtcService._internal() {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
     SocketService().callStream.listen((data) {
        final event = data['event'];
        final payload = data['data']; 
        
        switch (event) {
           case 'video_call_accept':
             handleAnswer(payload);
             break;
           case 'video_call_reject':
             onCallStateChange?.call("Rejected");
             // Cleanly end call state
             endCall();
             break;
           case 'video_call_end':
             onCallStateChange?.call("Ended");
             endCall();
             break;
           case 'video_call_ice':
             handleCandidate(payload);
             break;
        }
     });
  }

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream; 
  
  StreamStateCallback? onLocalStream;
  StreamStateCallback? onRemoteStream;
  CallStateCallback? onCallStateChange;
  
  String? _peerId;
  String? _connectionId; 
  
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'sdpSemantics': 'balanced', // or 'unified-plan'
  };

  // State
  bool isAudioEnabled = true;
  bool isVideoEnabled = true;

  // Track Global Call State to prevent duplicate screens
  bool _isCallActive = false; 
  bool get isCallActive => _isCallActive;

  void setCallActive(bool active) {
    _isCallActive = active;
  }

  // Renderers managed by Service to survive navigation
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _areRenderersInitialized = false;
  
  // Callbacks can now just signal UI to rebuild if needed, or we can use ValueNotifier
  // Keeping callbacks for compatibility, but passing stream is redundant if we use renderer directly.
  
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  Future<void> initializeRenderers() async {
    if (_areRenderersInitialized) return;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _areRenderersInitialized = true;
  }

  Future<void> disposeRenderers() async {
     if (!_areRenderersInitialized) return; // Prevent double disposal
     
     localRenderer.srcObject = null;
     remoteRenderer.srcObject = null;
     await localRenderer.dispose();
     await remoteRenderer.dispose();
     _areRenderersInitialized = false;
  }
  
  bool isRendererReady() => _areRenderersInitialized;

  Future<void> initCall(String peerId, bool video) async {
    if (_isCallActive) return; 
    _isCallActive = true;
    _peerId = peerId;
    
    try {
      await initializeRenderers();
      
      // Stop old peerConnection if exists
      if (_peerConnection != null) {
         _peerConnection!.close();
         _peerConnection = null;
      }

      await _createPeerConnection();
      
      // Always request audio, video optional
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': video ? {
            'facingMode': 'user',
            'width': {'ideal': 640},
            'height': {'ideal': 480},
        } : false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      if (!_isCallActive) {
         _localStream?.getTracks().forEach((t)=>t.stop());
         return;
      }

      // Attach local stream
      if (_areRenderersInitialized && video) {
         localRenderer.srcObject = _localStream;
      }
      onLocalStream?.call(_localStream!);

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
      
      // Create Offer
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      SocketService().emit('video_call_request', {
         'to': peerId,
         'from': AuthService().currentUserId, 
         'callType': video ? 'video' : 'audio',
         'offer': offer.toMap(),
      });
      
      onCallStateChange?.call("Calling...");
    } catch (e) {
      print("Init Call Error: $e");
      endCall();
    }
  }
  
  // Clean Rejection Helper
  void rejectCall(String to) {
     SocketService().emit('video_call_reject', {'to': to});
     endCall();
  }

  // Handle Incoming Call 
  Future<void> handleIncomingCall(Map<String, dynamic> data) async {
      // NOTE: We do NOT check if (_isCallActive) return; here because this method is called 
      // when the user hits 'Accept' on the incoming screen (which is already an active state).
      
      try {
        await initializeRenderers();
        
        // Stop old peerConnection if exists
        if (_peerConnection != null) {
           _peerConnection!.close();
           _peerConnection = null;
        }

        _connectionId = data['from']; 
        bool video = data['callType'] == 'video';
        final offerMap = data['offer'];
        if (offerMap == null) throw Exception("No offer data received");
        
        await _createPeerConnection();
        
        // Always request audio, video optional
        final mediaConstraints = <String, dynamic>{
          'audio': true,
          'video': video ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
          } : false,
        };
        
        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
        
        if (!_isCallActive) {
           _localStream?.getTracks().forEach((t)=>t.stop());
           return;
        }
        
        if (_localStream != null) {
          _localStream!.getTracks().forEach((track) {
            _peerConnection!.addTrack(track, _localStream!);
          });
          if (_areRenderersInitialized && video) {
             localRenderer.srcObject = _localStream;
          }
          onLocalStream?.call(_localStream!);
        }
        
        await _peerConnection!.setRemoteDescription(
           RTCSessionDescription(offerMap['sdp'], offerMap['type'])
        );
        
        RTCSessionDescription answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        
        SocketService().emit('video_call_accept', {
            'to': _connectionId,
            'from': AuthService().currentUserId,
            'answer': answer.toMap() 
        });
        
        onCallStateChange?.call("Connecting...");
        
      } catch (e) {
        print("Error handling incoming call: $e");
        endCall(); 
        rethrow;
      }
  }
  
  // ... (handleAnswer, handleCandidate unchanged) ...
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
           SocketService().emit('video_call_ice', {
              'to': _connectionId ?? _peerId,
              'candidate': candidate.toMap()
           });
        }
     };
     
     _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
           _remoteStream = event.streams[0];
           // Attach to Renderer IMMEDIATELY
           // Check safety
           if (_areRenderersInitialized) {
              remoteRenderer.srcObject = _remoteStream;
              onRemoteStream?.call(_remoteStream!);
           }
        }
     };
     
     _peerConnection!.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
              endCall();
        }
     };
  }

  void endCall({bool retainState = false}) {
     _localStream?.getTracks().forEach((track) => track.stop());
     _localStream?.dispose();
     
     _peerConnection?.close();
     _peerConnection = null;
     _localStream = null;
     _remoteStream = null;
     
     // Do NOT dispose renderers here; keep alive for next call
     if (_areRenderersInitialized) {
        localRenderer.srcObject = null;
        remoteRenderer.srcObject = null;
     }
     
     if (_connectionId != null || _peerId != null) {
        SocketService().emit('video_call_end', {'to': _connectionId ?? _peerId});
     }
     
     _peerId = null;
     _connectionId = null;
     
     if (!retainState) {
        _isCallActive = false;
        onCallStateChange?.call("Ended");
     }
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
        Helper.switchCamera(_localStream!.getVideoTracks()[0]);
     }
  }
}
