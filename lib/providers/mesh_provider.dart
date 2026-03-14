import 'dart:async';
import 'package:flutter/material.dart';
import 'package:crowd_link/services/mesh_service.dart';
import 'package:crowd_link/models/mesh_packet.dart';
import 'package:crowd_link/models/mesh_node.dart';
import 'package:crowd_link/models/gateway_request.dart';
import 'package:crowd_link/models/internet_packet.dart';
import 'package:crowd_link/services/auth_service.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crowd_link/services/notification_service.dart';

class MeshProvider with ChangeNotifier {
  final MeshService _meshService = MeshService();
  
  bool _isMeshActive = false;
  Map<String, MeshNode> _connectedPeers = {};
  List<MeshPacket> _receivedPackets = [];
  List<String> _logs = [];
  List<GatewayRequest> _requestQueue = [];
  GatewayRequest? _activeSession;
  Set<String> _friendMeshIds = {};
  String? _permissionError;
  List<InternetPacket> _pendingInternetRequests = [];
  Map<String, int> _unreadCounts = {};
  String? _activeMeshId;
  Set<String> _mutedMeshIds = {};
  Map<String, int> _clearTimes = {};
  Set<String> _deletedMessageIds = {};
  Map<String, int> _lastSeenTimes = {};
  
  bool get isAdvertising => _meshService.isAdvertising;
  bool get isDiscovering => _meshService.isDiscovering;

  bool get isMeshActive => _isMeshActive;
  Map<String, MeshNode> get connectedPeers => _connectedPeers;
  int get connectedPeerCount => _connectedPeers.length;
  List<MeshPacket> get receivedPackets => _receivedPackets;
  List<String> get logs => _logs;
  
  List<GatewayRequest> get requestQueue => _requestQueue;
  GatewayRequest? get activeSession => _activeSession;
  List<MeshNode> get gatewayNodes => _meshService.gatewayNodes;
  bool get isInternetAvailable => _meshService.isInternetAvailable;
  Set<String> get friendMeshIds => _friendMeshIds;
  String? get permissionError => _permissionError;
  Map<String, int> get unreadCounts => _unreadCounts;
  String? get activeMeshId => _activeMeshId;
  Set<String> get mutedMeshIds => _mutedMeshIds;

  List<MeshNode> get visiblePeers {
    return _connectedPeers.values
        .where((peer) => _friendMeshIds.contains(peer.meshId))
        .toList();
  }

  StreamSubscription? _peersSub;
  StreamSubscription? _packetSub;
  StreamSubscription? _logSub;
  StreamSubscription? _queueSub;
  StreamSubscription? _sessionSub;
  StreamSubscription? _promptSub;
  StreamSubscription? _friendsSub;

  MeshProvider() {
    _init();
    _loadMutedChats();
    _loadChatManagementData();
  }

  void _init() {
    _peersSub = _meshService.peersStream.listen((peers) {
      _connectedPeers = Map.from(peers);
      _checkAndFlushGatewayQueue();
      notifyListeners();
    });

    _packetSub = _meshService.messageStream.listen((packet) async {
      _receivedPackets.insert(0, packet);
      if (_receivedPackets.length > 500) _receivedPackets.removeLast();
      
      final profile = await _meshService.getUserProfile();
      final myMeshId = profile?['meshId'];

      // Update unread count if chat not active AND sender is a friend
      bool isFromFriend = _friendMeshIds.contains(packet.senderMeshId);
      bool isChatOpen = _activeMeshId == packet.senderMeshId;
      bool isMe = packet.senderMeshId == 'Me' || packet.senderMeshId == 'self' || (myMeshId != null && packet.senderMeshId == myMeshId);
      
      int lastSeen = _lastSeenTimes[packet.senderMeshId] ?? 0;
      bool isUnseen = packet.timestamp > lastSeen;

      if (!isChatOpen && !isMe && isFromFriend && isUnseen) {
        _unreadCounts[packet.senderMeshId] = (_unreadCounts[packet.senderMeshId] ?? 0) + 1;
        
        // Show notification if not muted
        if (!_mutedMeshIds.contains(packet.senderMeshId)) {
          final senderNode = _connectedPeers[packet.senderMeshId];
          final senderName = packet.metadata?['senderName'] ?? senderNode?.deviceName ?? 'Friend';
          
          if (packet.type == MeshPacketType.paymentRequest) {
            NotificationService.showPaymentNotification(
              senderName, 
              packet.metadata?['amount']?.toString() ?? '0',
              paymentId: packet.packetId
            );
          } else if (packet.type == MeshPacketType.message) {
            NotificationService.showMessageNotification(
              senderName, 
              packet.payload,
              packetId: packet.packetId,
              senderMeshId: packet.senderMeshId
            );
          }
        }
      } else if (packet.type == MeshPacketType.broadcast || packet.type == MeshPacketType.sos) {
         // Handle broadcast notification
         final senderName = packet.metadata?['senderName'] ?? 'Mesh User';
         NotificationService.showBroadcastNotification(
           senderName, 
           packet.payload,
           packetId: packet.packetId
         );
      }
      
      notifyListeners();
    });

    _logSub = _meshService.logStream.listen((log) {
      _logs.insert(0, "[${DateTime.now().toIso8601String().substring(11, 19)}] $log");
      if (_logs.length > 200) _logs.removeLast();
      notifyListeners();
    });

    _queueSub = _meshService.queueStream.listen((queue) {
      _requestQueue = List.from(queue);
      notifyListeners();
    });

    _sessionSub = _meshService.sessionStream.listen((session) {
      _activeSession = session;
      notifyListeners();
    });

    _promptSub = _meshService.incomingRequestPromptStream.listen((request) {
      _pendingIncomingRequest = request;
      notifyListeners();
    });

    _friendsSub = AuthService().friendsStream().listen((friends) {
      _friendMeshIds = friends.map((f) => f['meshId'] as String).toSet();
      _meshService.setFriendList(_friendMeshIds); // Notify service for security checks
      
      // Also listen to online messages for unread counts if mesh not available
      // Actually, MeshService already forwards online payment requests to messageStream
      notifyListeners();
    });
  }

  void setActiveChat(String? meshId) {
    _activeMeshId = meshId;
    if (meshId != null) {
      _unreadCounts[meshId] = 0;
      _lastSeenTimes[meshId] = DateTime.now().millisecondsSinceEpoch;
      _saveLastSeenTimes();
    }
    notifyListeners();
  }

  void resetUnreadCount(String meshId) {
    if (_unreadCounts[meshId] != 0) {
      _unreadCounts[meshId] = 0;
      _lastSeenTimes[meshId] = DateTime.now().millisecondsSinceEpoch;
      _saveLastSeenTimes();
      notifyListeners();
    }
  }

  Future<void> _saveLastSeenTimes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_seen_times', jsonEncode(_lastSeenTimes));
  }

  void _showApprovalDialog(GatewayRequest request) {
    // This is handled by UI listening to a getter or we can use a callback/navigator
    // However, Provider usually shouldn't show UI directly. 
    // I'll expose a 'pendingIncomingRequest' property.
  }

  GatewayRequest? _pendingIncomingRequest;
  GatewayRequest? get pendingIncomingRequest => _pendingIncomingRequest;

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  Future<void> clearChat(String meshId) async {
    _receivedPackets.removeWhere((p) => p.senderMeshId == meshId || p.destinationMeshId == meshId);
    _clearTimes[meshId] = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('clear_times', jsonEncode(_clearTimes));
    notifyListeners();
  }

  Future<void> deleteMessages(List<String> packetIds) async {
    _receivedPackets.removeWhere((p) => packetIds.contains(p.packetId));
    _deletedMessageIds.addAll(packetIds);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('deleted_messages', _deletedMessageIds.toList());
    notifyListeners();
  }

  bool isMessageDeleted(String? id, int? timestamp, String chatMeshId) {
    if (id != null && _deletedMessageIds.contains(id)) return true;
    if (timestamp != null && _clearTimes.containsKey(chatMeshId)) {
      if (timestamp <= _clearTimes[chatMeshId]!) return true;
    }
    return false;
  }

  bool isMuted(String meshId) {
    return _mutedMeshIds.contains(meshId);
  }

  Future<void> toggleMute(String meshId) async {
    if (_mutedMeshIds.contains(meshId)) {
      _mutedMeshIds.remove(meshId);
    } else {
      _mutedMeshIds.add(meshId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('muted_chats', _mutedMeshIds.toList());
    notifyListeners();
  }

  Future<void> _loadMutedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final muted = prefs.getStringList('muted_chats') ?? [];
    _mutedMeshIds = muted.toSet();
    notifyListeners();
  }

  Future<void> _loadChatManagementData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final deleted = prefs.getStringList('deleted_messages') ?? [];
    _deletedMessageIds = deleted.toSet();
    
    final clearTimesRaw = prefs.getString('clear_times');
    if (clearTimesRaw != null) {
      try {
        final decoded = jsonDecode(clearTimesRaw) as Map<String, dynamic>;
        _clearTimes = decoded.map((key, value) => MapEntry(key, value as int));
      } catch (_) {}
    }
    
    final lastSeenRaw = prefs.getString('last_seen_times');
    if (lastSeenRaw != null) {
      try {
        final decoded = jsonDecode(lastSeenRaw) as Map<String, dynamic>;
        _lastSeenTimes = decoded.map((key, value) => MapEntry(key, value as int));
      } catch (_) {}
    }
    
    notifyListeners();
  }

  Future<void> toggleMesh() async {
    _permissionError = null;
    if (_isMeshActive) {
      await _meshService.stopMesh();
      _isMeshActive = false;
    } else {
      // Check permissions first
      final bool granted = await _meshService.requestPermissions();
      if (!granted) {
        _permissionError = "Mesh networking requires Bluetooth and Location permissions.";
        notifyListeners();
        return;
      }

      // Check location service
      final bool locationEnabled = await _meshService.isLocationServiceEnabled();
      if (!locationEnabled) {
        _permissionError = "Please enable Location services to allow device discovery";
        notifyListeners();
        // Still try to start, as startMesh will prompt for it
      }

      await _meshService.startMesh();
      // Verifying if it actually started
      _isMeshActive = _meshService.isAdvertising || _meshService.isDiscovering;
      
      if (!_isMeshActive) {
        // If it failed to start, try to stop everything to be safe
        await _meshService.stopMesh();
        if (_permissionError == null) {
          _permissionError = "Failed to initialize mesh networking hardware.";
        }
      } else {
        _permissionError = null;
      }
    }
    notifyListeners();
  }

  Future<void> broadcastMessage(String text, {required bool isSos}) async {
    final profile = await _meshService.getUserProfile();
    final name = profile?['name'] ?? 'Device';
    final myMeshId = profile?['meshId'] ?? 'Unknown';

    await _meshService.broadcast(
      text, 
      type: isSos ? MeshPacketType.sos : MeshPacketType.broadcast,
      metadata: {'senderName': name, 'senderMeshId': myMeshId},
    );
  }

  Future<void> sendPaymentRequest(String destinationMeshId, String amount, String reason, {String? upiId}) async {
    final profile = await _meshService.getUserProfile();
    final myMeshId = profile?['meshId'] ?? 'Unknown';
    final name = profile?['name'] ?? 'Device';
    bool sent = false;

    // 1. Priority: Direct Firebase if local internet is available
    if (_meshService.isInternetAvailable) {
       final target = await AuthService().getUserByMeshId(destinationMeshId);
       final uid = target?['uid'];
       if (uid != null) {
         try {
           await AuthService().sendMessage(
             uid, 
             "Payment Request: ₹$amount",
             type: 'PAYMENT_REQUEST',
             metadata: {
               'amount': amount,
               'upiId': upiId,
               'note': reason,
               'senderMeshId': myMeshId,
             }
           );
           sent = true;
         } catch (_) {}
       }
    }

    // 2. Mesh: Try direct Mesh if not sent via internet
    if (!sent && _isMeshActive && isFriendNearby(destinationMeshId)) {
        MeshPacket packet = MeshPacket(
          senderMeshId: myMeshId,
          destinationMeshId: destinationMeshId,
          payload: "PAYMENT_REQUEST: $amount for $reason",
          timestamp: DateTime.now().millisecondsSinceEpoch,
          type: MeshPacketType.paymentRequest,
          metadata: {'amount': amount, 'reason': reason, 'senderName': name, 'upiId': upiId},
        );
        await _meshService.sendPacket(packet);
        _receivedPackets.insert(0, packet);
        sent = true;
    } 
    // 3. Use Gateway if active but not nearby
    else if (!sent && _isMeshActive) {
        await sendGatewayPaymentRequest(destinationMeshId, upiId ?? "friend@upi", amount, reason);
        sent = true;
    }

    if (!sent) {
      _logs.add("Unable to send payment request. Connect to internet or Mesh.");
    }

    notifyListeners();
  }

  Future<void> sendPaymentConfirmation(String destinationMeshId, String amount) async {
    final profile = await _meshService.getUserProfile();
    final myMeshId = profile?['meshId'] ?? 'Unknown';
    final name = profile?['name'] ?? 'Device';

    MeshPacket packet = MeshPacket(
      senderMeshId: myMeshId,
      destinationMeshId: destinationMeshId,
      payload: "PAID: ₹$amount",
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: MeshPacketType.paymentConfirmation,
      metadata: {'amount': amount, 'senderName': name},
    );

    await _meshService.sendPacket(packet);
    _receivedPackets.insert(0, packet);
    notifyListeners();
  }

  Future<bool> sendDirectMessage(String destinationMeshId, String text) async {
    final profile = await _meshService.getUserProfile();
    final myMeshId = profile?['meshId'] ?? 'Unknown';
    final name = profile?['name'] ?? 'Device';

    MeshPacket packet = MeshPacket(
      senderMeshId: myMeshId,
      destinationMeshId: destinationMeshId,
      payload: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: MeshPacketType.message,
      ttl: 3,
      metadata: {'senderName': name},
    );

    try {
      await _meshService.sendPacket(packet);
      _receivedPackets.insert(0, packet); // Add to local list so it shows in UI
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  bool isFriendNearby(String meshId) {
    return _connectedPeers.values.any((node) => node.meshId == meshId);
  }

  Future<void> requestInternet(String gatewayEndpointId) async {
    await _meshService.requestInternetAccess(gatewayEndpointId);
  }

  void approveGatewayRequest(String requestId) {
    _meshService.approveRequest(requestId);
  }

  void denyGatewayRequest(String requestId) {
    _meshService.denyRequest(requestId);
  }

  Future<void> initiateMicroInternetRequest(String gatewayEndpointId, InternetPacket packet) async {
    final meshPacket = MeshPacket(
      senderMeshId: (await _meshService.getUserProfile())?['meshId'] ?? 'Client',
      payload: jsonEncode(packet.toJson()),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: MeshPacketType.internetRequest,
    );
    await _meshService.sendPacket(meshPacket);
  }

  void _checkAndFlushGatewayQueue() {
    if (_pendingInternetRequests.isEmpty) return;
    
    final gateways = gatewayNodes;
    if (gateways.isNotEmpty) {
      final gatewayId = gateways.first.endpointId;
      debugPrint("[GATEWAY] Flushing queue with ${gateways.first.deviceName}...");
      
      for (var packet in _pendingInternetRequests) {
        initiateMicroInternetRequest(gatewayId, packet);
      }
      _pendingInternetRequests.clear();
      notifyListeners();
    }
  }

  Future<void> sendGatewayMessage(String receiverMeshId, String receiverUid, String text) async {
    final myProfile = await getUserProfile();
    final myMeshId = myProfile?['meshId'] ?? 'Unknown';

    final ip = InternetPacket(
      requestId: const Uuid().v4(),
      senderMeshId: myMeshId,
      serviceType: InternetServiceType.sendMessage,
      payload: {
        'senderId': myMeshId,
        'receiverId': receiverMeshId,
        'receiverUid': receiverUid,
        'message': text,
        'viaGateway': true,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    final gateways = gatewayNodes;
    if (gateways.isEmpty) {
      _pendingInternetRequests.add(ip);
      _logs.add("No internet gateway available. Message queued.");
    } else {
      await initiateMicroInternetRequest(gateways.first.endpointId, ip);
    }
    
    // Add to local packets so it shows in the UI
    final localPacket = MeshPacket(
      senderMeshId: myMeshId,
      destinationMeshId: receiverMeshId,
      payload: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: MeshPacketType.message,
      metadata: {'viaGateway': true},
    );
    _receivedPackets.insert(0, localPacket);
    notifyListeners();
  }

  Future<void> sendGatewayPaymentRequest(String receiverMeshId, String upiId, String amount, String reason) async {
    final myProfile = await getUserProfile();
    final myMeshId = myProfile?['meshId'] ?? 'Unknown';

    final ip = InternetPacket(
      requestId: const Uuid().v4(),
      senderMeshId: myMeshId,
      serviceType: InternetServiceType.upiPayment,
      payload: {
        'senderId': myMeshId,
        'receiverId': receiverMeshId,
        'upiId': upiId,
        'amount': amount,
        'note': reason,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    final gateways = gatewayNodes;
    if (gateways.isEmpty) {
      _pendingInternetRequests.add(ip);
      _logs.add("No internet gateway available. Payment request queued.");
      notifyListeners();
    } else {
      await initiateMicroInternetRequest(gateways.first.endpointId, ip);
    }
  }

  Future<Map<String, dynamic>?> getUserProfile() => _meshService.getUserProfile();

  @override
  void dispose() {
    _peersSub?.cancel();
    _packetSub?.cancel();
    _logSub?.cancel();
    _queueSub?.cancel();
    _sessionSub?.cancel();
    _promptSub?.cancel();
    _friendsSub?.cancel();
    _meshService.stopMesh();
    super.dispose();
  }
}
