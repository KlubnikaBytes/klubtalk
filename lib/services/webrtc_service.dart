import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:whatsapp_clone/services/auth_service.dart';
import 'package:whatsapp_clone/services/socket_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:whatsapp_clone/config/api_config.dart';
import 'package:flutter/services.dart'; // For MethodChannel

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
             print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
             print("🚫 RECEIVED video_call_reject event from ${payload?['from']}");
             
             // 🚫 Guard: Don't process our own reject event
             final currentUserId = AuthService().currentUserId;
             if (payload?['from'] == currentUserId) {
                print("⏭️ SKIP: This is our own reject event, ignoring");
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
                break;
             }
             
             print("🚫 Calling onCallStateChange with 'Rejected'");
             onCallStateChange?.call("Rejected");
             print("🚫 Now calling endCall() to cleanup");
             // Cleanly end call state
             endCall();
             print("🚫 Call rejection handled");
             print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
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
  
  // Debounce for reject to prevent duplicate calls
  DateTime? _lastRejectTime;
  
  // Track when pendingDecline was set for debugging
  DateTime? _pendingDeclineSetTime;
  
  // Track declined caller ID to prevent showing IncomingCallScreen
  String? _declinedCallerId; 
  
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
  DateTime? _callStartTime;
  bool _isCaller = false;
  String? _remoteUserId; // Peer ID (Connection ID or Peer ID)

  // Track Global Call State
  bool _isCallActive = false; 
  bool get isCallActive => _isCallActive;
  bool _logSaved = false;
  
  // Public getter for declined caller ID
  String get declinedCallerId => _declinedCallerId ?? '';

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
    _remoteUserId = peerId;
    _isCaller = true;
    _logSaved = false;
    isVideoEnabled = video;
    isAudioEnabled = true;
    
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
      
      // 🎵 Play Outgoing Ringtone (Native)
      try {
        const platform = MethodChannel('com.example.whatsapp_clone/ringtone');
        await platform.invokeMethod('playOutgoing');
      } catch (e) {
        print("Ringtone Error: $e");
      }
    } catch (e) {
      print("Init Call Error: $e");
      endCall();
    }
  }
  
  // Clean Rejection Helper
  void rejectCall(String to) {
     final now = DateTime.now();
     final timestamp = now.toIso8601String();
     print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
     print("🔻 [$timestamp] WebrtcService.rejectCall() ENTRY");
     print("🔻 [$timestamp] Target: '$to'");
     print("🔻 [$timestamp] Current pendingDecline: $pendingDecline");
     
     // 🚫 DEBOUNCE: Prevent duplicate calls within 2 seconds
     if (_lastRejectTime != null) {
        final timeSinceLastReject = now.difference(_lastRejectTime!);
        print("🔻 [$timestamp] Time since last reject: ${timeSinceLastReject.inMilliseconds}ms");
        if (timeSinceLastReject.inSeconds < 2) {
           print("⏭️ [$timestamp] SKIP: rejectCall already executed ${timeSinceLastReject.inMilliseconds}ms ago");
           print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
           return;
        }
     }
     _lastRejectTime = now;
     
     print("🔻 [$timestamp] Setting pendingDecline = true AND tracking declined caller: $to");
     pendingDecline = true;
     _declinedCallerId = to; // Track who we declined
     _pendingDeclineSetTime = now;
     
     print("🔻 [$timestamp] Emitting 'video_call_reject' socket event");
     SocketService().emit('video_call_reject', {'to': to, 'from': AuthService().currentUserId});
     
     print("🔻 [$timestamp] Calling endCall()");
     endCall();
     
     // DON'T reset pendingDecline immediately - keep it set for 10 seconds for cold start scenarios
     Future.delayed(const Duration(seconds: 10), () {
        final resetTime = DateTime.now().toIso8601String();
        print("🔻 [$resetTime] Resetting pendingDecline and _declinedCallerId (after 10s delay)");
        pendingDecline = false;
        _declinedCallerId = null;
        _pendingDeclineSetTime = null;
     });
     
     print("🔻 [$timestamp] rejectCall() EXIT (pendingDecline will reset in 10s)");
     print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  }

  // Track pending acceptance
  bool pendingAutoAccept = false;

  void setPendingAutoAccept(bool value) {
     pendingAutoAccept = value;
  }

  // Track pending decline (when declined from notification)
  bool pendingDecline = false;

  void setPendingDecline(bool value) {
     pendingDecline = value;
     print("🔻 pendingDecline set to: $value");
  }

  // Handle Incoming Call 
  Future<void> handleIncomingCall(Map<String, dynamic> data) async {
      try {
        await initializeRenderers();
        
        // Stop old peerConnection if exists
        if (_peerConnection != null) {
           _peerConnection!.close();
           _peerConnection = null;
        }

        _connectionId = data['from']; 
        _remoteUserId = data['from'];
        _isCaller = false; 
        _logSaved = false;
        bool video = data['callType'] == 'video';
        
        isVideoEnabled = video; 
        isAudioEnabled = true;

        final offerMap = data['offer'];
        if (offerMap == null || offerMap == '{}') { // Handle empty json string
            // Missing offer (Notification Payload too small)
            print("⚠️ handleIncomingCall: Missing Offer! Setting pendingAutoAccept = true and Waiting for Socket...");
            setPendingAutoAccept(true);
            onCallStateChange?.call("Connecting..."); // Show connecting while waiting
            return;
        }
        
        // If we have offer, proceed normally
        await processIncomingOffer(offerMap, video);
        
      } catch (e) {
        print("Error handling incoming call: $e");
        endCall(); 
        rethrow;
      }
  }

  // Helper to process offer once available
  Future<void> processIncomingOffer(dynamic offerMap, bool video) async {
       print("✅ processing Incoming Offer...");
       if (offerMap is String) {
          offerMap = jsonDecode(offerMap); // Handle stringified offer
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
        
        if (!_isCallActive && !pendingAutoAccept) { 
           // NOTE: _isCallActive might be false initially, but if pending, we continue?
           // Actually call screen sets active.
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
        _callStartTime = DateTime.now(); 
        pendingAutoAccept = false; // Reset
  }
  
  // ... (handleAnswer, handleCandidate unchanged) ...
  // Handle Answer (Caller receives answer)
  Future<void> handleAnswer(Map<String, dynamic> data) async {
      if (_peerConnection != null) {
         await _peerConnection!.setRemoteDescription(
            RTCSessionDescription(data['answer']['sdp'], data['answer']['type'])
         );
         onCallStateChange?.call("On Call");
         _callStartTime = DateTime.now();
         const MethodChannel('com.example.whatsapp_clone/ringtone').invokeMethod('stop'); // 🛑 Stop Ringtone
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
     
     if (!retainState) {
        _isCallActive = false;
        onCallStateChange?.call("Ended");
        const MethodChannel('com.example.whatsapp_clone/ringtone').invokeMethod('stop');
     }

     // Save Log
     if (_remoteUserId != null && !_logSaved) {
        _logSaved = true;
        final duration = _callStartTime != null 
             ? DateTime.now().difference(_callStartTime!).inSeconds 
             : 0;
        
        // Determine Status
        String status = 'completed';
        if (duration == 0) {
           status = _isCaller ? 'missed' : 'rejected'; 
        }

        saveCallLog(
           callerId: _isCaller ? AuthService().currentUserId ?? '' : _remoteUserId!,
           receiverId: _isCaller ? _remoteUserId! : AuthService().currentUserId ?? '',
           callType: isVideoEnabled ? 'video' : 'voice', 
           status: status,
           duration: duration
        );
        
        _callStartTime = null;
        _remoteUserId = null;
     }
     
     _peerId = null;
     _connectionId = null;
  }

  Future<void> saveCallLog({
    required String callerId,
    required String receiverId,
    required String callType,
    required int duration,
    required String status,
  }) async {
    try {
      final token = AuthService().token;
      if (token == null) return;
      
      // Validation: Ensure IDs are valid string IDs (basic check)
      if (callerId.isEmpty || receiverId.isEmpty || callerId == "null" || receiverId == "null") {
          print("⚠️ Skipping saveCallLog: Invalid caller/receiver ID. From: $callerId To: $receiverId");
          return;
      }

      final body = {
          "from": callerId,
          "to": receiverId,
          "type": callType,
          "status": status,
          "duration": duration,
          "callTime": DateTime.now().toIso8601String(), // FIX: Use DEVICE time, explicit NOW
      };

      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/calls/save'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(body)
      );
      print("✅ Call Log Saved: ${jsonEncode(body)}");
    } catch (e) {
      print("❌ Failed to save call log: $e");
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
