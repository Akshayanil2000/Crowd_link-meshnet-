import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart' as loc;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crowd_link/models/mesh_packet.dart';
import 'package:crowd_link/models/mesh_node.dart';
import 'package:crowd_link/models/gateway_request.dart';
import 'package:http/http.dart' as http;
import 'package:telephony/telephony.dart';
import 'package:crowd_link/models/internet_packet.dart';
import 'package:crowd_link/services/auth_service.dart';
import 'package:crowd_link/services/permission_service.dart';
import 'package:crowd_link/services/notification_service.dart';

class MeshService {
  static final MeshService _instance = MeshService._internal();
  factory MeshService() => _instance;
  MeshService._internal();

  final Strategy strategy = Strategy.P2P_CLUSTER;
  final String serviceId = "com.crowdlink.mesh";
  
  // State
  final Map<String, MeshNode> connectedPeers = {};
  final Set<String> _packetCache = {}; // To prevent loops
  final Set<String> _receivedBroadcastIds = {}; // Specifically for UI deduplication
  bool isAdvertising = false;
  bool isDiscovering = false;
  
  // Gateway State
  bool _isInternetAvailable = false;
  bool _isGatewayModeEnabled = true; // From settings
  final List<GatewayRequest> _requestQueue = [];
  GatewayRequest? _activeSession;
  Timer? _sessionTimer;
  final Map<String, StreamSubscription> _routingSubs = {};
  Set<String> _friendMeshIds = {};
  Set<String> _processedRequestIds = {};
  final Telephony _telephony = Telephony.instance;
  final Map<String, StreamSubscription> _onlineMsgSubs = {};

  // Controllers for Provider integration
  final StreamController<Map<String, MeshNode>> _peersController = StreamController.broadcast();
  final StreamController<MeshPacket> _packetStreamController = StreamController.broadcast();
  final StreamController<String> _logController = StreamController.broadcast();
  final StreamController<List<GatewayRequest>> _queueController = StreamController.broadcast();
  final StreamController<GatewayRequest?> _sessionController = StreamController.broadcast();
  final StreamController<GatewayRequest?> _incomingRequestPromptController = StreamController.broadcast();

  Stream<Map<String, MeshNode>> get peersStream => _peersController.stream;
  Stream<MeshPacket> get messageStream => _packetStreamController.stream;
  Stream<String> get logStream => _logController.stream;
  Stream<List<GatewayRequest>> get queueStream => _queueController.stream;
  Stream<GatewayRequest?> get sessionStream => _sessionController.stream;
  Stream<GatewayRequest?> get incomingRequestPromptStream => _incomingRequestPromptController.stream;

  List<MeshNode> get gatewayNodes => connectedPeers.values.where((n) => n.isGateway).toList();
  bool get isInternetAvailable => _isInternetAvailable;
  List<GatewayRequest> get requestQueue => _requestQueue;
  GatewayRequest? get activeSession => _activeSession;

  final AuthService _authService = AuthService();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;

  void _log(String message) {
    debugPrint("[MeshService] $message");
    _logController.add(message);
  }

  Future<Map<String, dynamic>?> getUserProfile() => _authService.getUserProfile();

  void setFriendList(Set<String> friends) {
    _friendMeshIds = friends;
    _log("Friend list updated: ${friends.length} friends");
    _listenForOnlineActivities();
  }

  void _listenForOnlineActivities() {
    _authService.friendsStream().listen((friends) {
      for (var f in friends) {
        final uid = f['uid'];
        if (_onlineMsgSubs.containsKey(uid)) continue;

        _onlineMsgSubs[uid] = _authService.messagesStream(uid).listen((messages) {
          for (var m in messages) {
            String msgId = m['id'] ?? m['timestamp'].toString();
            if (!_processedRequestIds.contains(msgId) && m['senderId'] == uid) {
              _processedRequestIds.add(msgId);
              
              MeshPacketType type = MeshPacketType.message;
              if (m['type'] == 'PAYMENT_REQUEST') type = MeshPacketType.paymentRequest;
              if (m['type'] == 'PAYMENT_CONFIRMATION') type = MeshPacketType.paymentConfirmation;

              final packet = MeshPacket(
                senderMeshId: m['senderMeshId'] ?? f['meshId'] ?? 'Online',
                destinationMeshId: 'Me',
                payload: m['text'] ?? '',
                timestamp: m['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
                type: type,
                metadata: Map<String, dynamic>.from(m),
              );
              _packetStreamController.add(packet);
            }
          }
        });
      }
    });
  }

  /// Request all necessary permissions for Nearby Connections
  Future<bool> requestPermissions() async {
    return await PermissionService.requestAllPermissions();
  }

  Future<bool> isLocationServiceEnabled() async {
    return await PermissionService.isLocationServiceEnabled();
  }

  /// Start the mesh node (both discovery and advertising)
  Future<void> startMesh() async {
    _log("Initializing mesh networking...");
    if (!await requestPermissions()) {
      _log("Permissions denied. Cannot start mesh.");
      _logController.add("Mesh networking requires Bluetooth and Location permissions.");
      return;
    }

    // Check if Location Service is enabled
    bool locationEnabled = await PermissionService.isLocationServiceEnabled();
    if (!locationEnabled) {
      _log("Location services disabled. Prompting...");
      _logController.add("Please enable Location services to allow device discovery");
      locationEnabled = await PermissionService.requestLocationService();
      if (!locationEnabled) {
        _log("Location services still disabled. Discovery might fail.");
      }
    }

    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (e) {
      _log("Error during mesh reset: $e");
    }

    final profile = await _authService.getUserProfile();
    final meshId = profile?['meshId'] ?? 'Unknown';
    final name = profile?['name'] ?? 'Device';

    _log("Starting mesh for $name ($meshId)");
    
    // Load settings
    final prefs = await SharedPreferences.getInstance();
    _isGatewayModeEnabled = prefs.getBool('enable_gateway') ?? true;

    // Check internet
    await _updateConnectivityStatus();
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged.listen((_) => _updateConnectivityStatus());

    final bool canBeGateway = _isInternetAvailable && _isGatewayModeEnabled;
    final String endpointMetadata = "$meshId|$name|$canBeGateway";

    await _startAdvertising(endpointMetadata, meshId);
    await Future.delayed(const Duration(seconds: 1));
    await _startDiscovery(endpointMetadata);

    if (isAdvertising || isDiscovering) {
      NotificationService.showMeshStatus(true, "Connected to nearby devices");
    }
  }

  Future<void> _updateConnectivityStatus() async {
    final results = await _connectivity.checkConnectivity();
    _isInternetAvailable = results.any((r) => r != ConnectivityResult.none);
    _log("Internet status updated: $_isInternetAvailable");
    
    // If status changed and we are advertising, we might need to restart advertising?
    // For now, handshakes will handle live updates.
  }


  Future<void> stopMesh() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    connectedPeers.clear();
    _peersController.add(connectedPeers);
    isAdvertising = false;
    isDiscovering = false;
    _log("Mesh networking stopped");
    NotificationService.showMeshStatus(false, "");
  }

  Future<void> _startAdvertising(String name, String metadata) async {
    try {
      bool success = await Nearby().startAdvertising(
        name,
        strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: serviceId,
      );
      isAdvertising = success;
      _log("Advertising started: $success");
    } catch (e) {
      isAdvertising = false;
      _log("Error starting advertising: $e");
    }
  }

  Future<void> _startDiscovery(String name) async {
    try {
      bool success = await Nearby().startDiscovery(
        name,
        strategy,
        onEndpointFound: (endpointId, discoveredName, serviceId) {
          _log("Node discovered! ID: $endpointId, Meta: $discoveredName");
          
          // Try to pre-register if name contains metadata
          if (discoveredName.contains('|')) {
            final parts = discoveredName.split('|');
            _registerPeerFromMeta(endpointId, parts[0], parts[1], 
              parts.length > 2 ? parts[2].toLowerCase() == 'true' : false);
          }

          _requestConnection(endpointId, name);
        },
        onEndpointLost: (endpointId) {
          _log("Node lost: $endpointId");
          connectedPeers.remove(endpointId);
          _peersController.add(connectedPeers);
        },
        serviceId: serviceId,
      );
      isDiscovering = success;
      _log("Discovery mode: ${success ? 'ACTIVE' : 'FAILED'}");
    } catch (e) {
      isDiscovering = false;
      _log("Critical discovery error: $e");
    }
  }

  void _requestConnection(String endpointId, String name) async {
    try {
      await Nearby().requestConnection(
        name,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      _log("Error requesting connection to $endpointId: $e");
    }
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    _log("Connection request from ${info.endpointName} ($endpointId)");
    
    // Auto-accept
    Nearby().acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpointId, payload) {
        _log("Payload received from $endpointId type: ${payload.type}");
        if (payload.type == PayloadType.BYTES) {
          _handleIncomingRawData(endpointId, payload.bytes!);
        }
      },
      onPayloadTransferUpdate: (endpointId, update) {
        if (update.status == PayloadStatus.FAILURE) {
          _log("Payload transfer FAILED for $endpointId");
        }
      },
    );
  }

  void _onConnectionResult(String endpointId, Status status) async {
    _log("Connection result for $endpointId: ${status.name}");
    if (status == Status.CONNECTED) {
      // Need to exchange mesh IDs if not already known from name
      // For now, assume endpointName contains metadata: "meshId|name|isGateway"
      // Wait, endpointName comes from advertising/discovery.
      
      // Let's create a temporary node entry. 
      // Ideally we should send a handshake packet.
      _sendHandshake(endpointId);
    } else {
      connectedPeers.remove(endpointId);
      _peersController.add(connectedPeers);
    }
  }

  void _onDisconnected(String endpointId) {
    _log("Disconnected from $endpointId");
    connectedPeers.remove(endpointId);
    _peersController.add(connectedPeers);
  }

  // ─── Packet Handling & Mesh Logic ───────────────────────────────────────────

  void _handleIncomingRawData(String fromEndpointId, Uint8List data) async {
    try {
      String jsonStr = utf8.decode(data);
      MeshPacket packet = MeshPacket.deserialize(jsonStr);
      
      // 1. Loop prevention
      if (_packetCache.contains(packet.packetId)) return;
      _packetCache.add(packet.packetId);
      // Keep cache small
      if (_packetCache.length > 500) _packetCache.remove(_packetCache.first);

      _log("Received packet ${packet.packetId} type ${packet.type} from peer");

      // Loop prevention for broadcasts
      if (packet.type == MeshPacketType.broadcast || packet.type == MeshPacketType.sos) {
        if (_receivedBroadcastIds.contains(packet.packetId)) return;
        _receivedBroadcastIds.add(packet.packetId);
        if (_receivedBroadcastIds.length > 500) _receivedBroadcastIds.remove(_receivedBroadcastIds.first);
      }

      // 2. Handle Handshake (Special system packet)
      if (packet.type == MeshPacketType.heartbeat) {
        _registerPeer(fromEndpointId, packet);
        return;
      }

      // 3. Handle Internet Request
      if (packet.type == MeshPacketType.internetRequest) {
        _handleInternetRequest(fromEndpointId, packet);
        return;
      }

      // 4. Handle Internet Response
      if (packet.type == MeshPacketType.internetResponse) {
        _handleInternetResponse(packet);
        return;
      }

      // 5. Deliver if it's for us or it's a broadcast
      bool isForMe = packet.destinationMeshId == null || await _isMyMeshId(packet.destinationMeshId!);
      if (isForMe) {
        _packetStreamController.add(packet);
        _handleNotifications(packet);
      }

      // 6. Relay logic
      if (packet.ttl > 0 && (packet.destinationMeshId == null || !isForMe)) {
        _relayPacket(packet, excludeEndpointId: fromEndpointId);
      }
    } catch (e) {
      _log("Error parsing incoming data: $e");
    }
  }

  Future<bool> _isMyMeshId(String meshId) async {
    final profile = await _authService.getUserProfile();
    return profile?['meshId'] == meshId;
  }

  void _registerPeerFromMeta(String endpointId, String meshId, String name, bool isGateway) {
    connectedPeers[endpointId] = MeshNode(
      endpointId: endpointId,
      meshId: meshId,
      deviceName: name,
      username: name,
      isGateway: isGateway,
      lastSeen: DateTime.now(),
    );
    _peersController.add(connectedPeers);
  }

  void _registerPeer(String endpointId, MeshPacket heartbeat) {
    final meta = heartbeat.metadata;
    if (meta == null) return;

    connectedPeers[endpointId] = MeshNode(
      endpointId: endpointId,
      meshId: heartbeat.senderMeshId,
      deviceName: meta['name'] ?? 'Unknown',
      username: meta['name'] ?? 'Unknown',
      isGateway: meta['isGateway'] ?? false,
      lastSeen: DateTime.now(),
    );
    _peersController.add(connectedPeers);
    _log("Peer registered: ${heartbeat.senderMeshId}, Gateway: ${meta['isGateway']}");
  }

  void _relayPacket(MeshPacket packet, {String? excludeEndpointId}) {
    packet.ttl -= 1;
    String data = packet.serialize();
    Uint8List bytes = Uint8List.fromList(utf8.encode(data));

    connectedPeers.forEach((endpointId, node) {
      if (endpointId != excludeEndpointId) {
        Nearby().sendBytesPayload(endpointId, bytes);
      }
    });
  }

  Future<void> sendPacket(MeshPacket packet) async {
    _packetCache.add(packet.packetId);
    
    // Also add to local stream so UI updates immediately
    _packetStreamController.add(packet);

    final Uint8List bytes = Uint8List.fromList(utf8.encode(packet.serialize()));
    await _sendPayloadToAllEndpoints(bytes);
  }

  Future<void> _sendPayloadToAllEndpoints(Uint8List bytes) async {
    for (var endpointId in connectedPeers.keys) {
      Nearby().sendBytesPayload(endpointId, bytes).catchError((e) => _log("Send failed to $endpointId: $e"));
    }
  }

  void _sendHandshake(String endpointId) async {
    final profile = await _authService.getUserProfile();
    final meshId = profile?['meshId'] ?? 'Unknown';
    final name = profile?['name'] ?? 'Device';

    MeshPacket handshake = MeshPacket(
      senderMeshId: meshId,
      payload: "HEARTBEAT",
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: MeshPacketType.heartbeat,
      ttl: 1, // Don't relay handshakes
      metadata: {
        'name': name,
        'isGateway': _isInternetAvailable && _isGatewayModeEnabled,
      },
    );

    Uint8List bytes = Uint8List.fromList(utf8.encode(handshake.serialize()));
    await Nearby().sendBytesPayload(endpointId, bytes);
  }

  /// Broadcast a message to the entire mesh
  Future<void> broadcast(String text, {MeshPacketType type = MeshPacketType.broadcast, Map<String, dynamic>? metadata}) async {
    final profile = await _authService.getUserProfile();
    final meshId = profile?['meshId'] ?? 'Unknown';
    final name = profile?['name'] ?? 'Device';

    Map<String, dynamic> finalMeta = {'senderName': name};
    if (metadata != null) finalMeta.addAll(metadata);

    MeshPacket packet = MeshPacket(
      senderMeshId: meshId,
      payload: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: type,
      ttl: 3,
      metadata: finalMeta,
    );

    await sendPacket(packet);
  }

  // ─── Internet Gateway Implementation ───────────────────────────────────────

  void _handleInternetRequest(String endpointId, MeshPacket packet) async {
    if (!_isInternetAvailable || !_isGatewayModeEnabled) return;

    _log("[GATEWAY] Incoming internet request from ${packet.senderMeshId}");

    // Parse Micro-Internet Packet
    InternetPacket? internetPacket;
    try {
      internetPacket = InternetPacket.fromJson(jsonDecode(packet.payload));
    } catch (e) {
      _log("Invalid internet packet payload: $e");
      // Fallback for old style approval request if necessary, 
      // but user wants Micro-Internet Model now.
    }

    final prefs = await SharedPreferences.getInstance();
    
    // Security Validation
    if (internetPacket != null) {
      bool isFriend = _friendMeshIds.contains(packet.senderMeshId);
      
      if (internetPacket.serviceType == InternetServiceType.upiPayment || 
          internetPacket.serviceType == InternetServiceType.smsSend) {
        
        bool friendOnly = prefs.getBool('gateway_friend_only_${internetPacket.serviceType.name}') ?? true;
        
        if (friendOnly && !isFriend) {
          _log("[SECURITY] Denying ${internetPacket.serviceType} from non-friend ${packet.senderMeshId}");
          _sendInternetResponse(packet.senderMeshId, endpointId, internetPacket.requestId, "error", "Security: Service restricted to friends.");
          return;
        }
      }
    }

    // FCFS: Add to queue
    final request = GatewayRequest(
      requestId: packet.packetId,
      senderMeshId: packet.senderMeshId,
      endpointId: endpointId,
      timestamp: packet.timestamp,
      status: GatewayRequestStatus.waiting,
      internetPacket: internetPacket,
    );

    _requestQueue.add(request);
    _queueController.add(_requestQueue);

    // Also notify packet stream so it shows in Activity
    _packetStreamController.add(packet);

    _processNextRequest();
  }

  void _processNextRequest() async {
    if (_activeSession != null || _requestQueue.isEmpty) return;

    final nextRequest = _requestQueue.first;
    
    // Auto-approve or prompt?
    // For Micro-Internet, we might want to process directly or keep the session model.
    // User asked for sequentially processing.
    
    // If it's a simple API call, we can just do it.
    // If it's a full session (old model), keep it.
    
    _startGatewaySession(nextRequest);
  }

  void approveRequest(String requestId) {
    if (_requestQueue.isEmpty) return;
    
    final request = _requestQueue.first;
    if (request.requestId == requestId) {
      _incomingRequestPromptController.add(null);
      _startGatewaySession(request);
    }
  }

  void denyRequest(String requestId) {
    if (_requestQueue.isEmpty) return;
    
    final request = _requestQueue.first;
    if (request.requestId == requestId) {
      _incomingRequestPromptController.add(null);
      request.status = GatewayRequestStatus.denied;
      _requestQueue.removeAt(0);
      _queueController.add(_requestQueue);
      
      // Notify client
      _sendInternetDenial(request);
      
      _processNextRequest();
    }
  }

  void _sendInternetDenial(GatewayRequest request) async {
    final profile = await _authService.getUserProfile();
    final myMeshId = profile?['meshId'] ?? 'Gateway';

    MeshPacket denial = MeshPacket(
      senderMeshId: myMeshId,
      destinationMeshId: request.senderMeshId,
      payload: "INTERNET_DENIED",
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: MeshPacketType.internetResponse,
      ttl: 1,
    );

    Uint8List bytes = Uint8List.fromList(utf8.encode(denial.serialize()));
    Nearby().sendBytesPayload(request.endpointId, bytes);
  }

  void _startGatewaySession(GatewayRequest request) async {
    _activeSession = request;
    request.status = GatewayRequestStatus.active;
    _sessionController.add(_activeSession);
    _queueController.add(_requestQueue);

    _log("[GATEWAY] Processing request for ${request.senderMeshId}");

    if (request.internetPacket != null) {
      await _executeMicroInternetRequest(request.internetPacket!, request.endpointId);
    } else {
      _log("[GATEWAY] No internet packet found in request, skipping execution.");
    }
    
    _endGatewaySession(); 
  }

  Future<void> _executeMicroInternetRequest(InternetPacket ip, String endpointId) async {
    _log("[GATEWAY] Executing ${ip.serviceType} for ${ip.senderMeshId}");
    
    String responseData = "";
    String status = "success";

    try {
      switch (ip.serviceType) {
        case InternetServiceType.httpGet:
          final url = ip.payload['url'];
          final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
          responseData = res.body;
          break;
        case InternetServiceType.httpPost:
          final url = ip.payload['url'];
          final body = ip.payload['body'];
          final res = await http.post(Uri.parse(url), body: body).timeout(const Duration(seconds: 10));
          responseData = res.body;
          break;
        case InternetServiceType.smsSend:
          final number = ip.payload['number'];
          final text = ip.payload['text'];
          bool smsGranted = await PermissionService.checkSmsPermissions();
          if (!smsGranted) {
            _log("[PERMISSION] Requesting SMS permission on gateway device...");
            smsGranted = await PermissionService.requestSmsPermission();
          }
          
          if (smsGranted) {
            await _telephony.sendSms(to: number, message: text);
            responseData = "SMS Sent";
          } else {
            status = "error";
            responseData = "SMS permission denied on gateway device";
          }
          break;
        case InternetServiceType.sendMessage:
          // Forward message to Firebase via AuthService
          final receiverId = ip.payload['receiverId'];
          final receiverUid = ip.payload['receiverUid'];
          final message = ip.payload['message'];
          
          String targetUid = receiverUid;
          if (targetUid.isEmpty) {
            final targetUser = await _authService.getUserByMeshId(receiverId);
            targetUid = targetUser?['uid'] ?? '';
          }
          
          final senderUser = await _authService.getUserByMeshId(ip.senderMeshId);
          final senderUid = senderUser?['uid'] ?? '';

          if (targetUid.isNotEmpty && senderUid.isNotEmpty) {
            await _authService.sendMessageOnBehalf(
              senderUid,
              targetUid, 
              message, 
              metadata: {'viaGateway': true, 'senderMeshId': ip.senderMeshId}
            );
            responseData = "SUCCESS";
            // Start listening for replies to route back
            _startRoutingReplies(targetUid, ip.senderMeshId, endpointId);
          } else {
            status = "error";
            responseData = "Receiver or Sender not found";
          }
          break;
        case InternetServiceType.upiPayment:
          // Forward payment request to Firebase as a structured message
          final receiverId = ip.payload['receiverId'];
          final upiId = ip.payload['upiId'];
          final amount = ip.payload['amount'];
          final note = ip.payload['note'];

          final targetUser = await _authService.getUserByMeshId(receiverId);
          final targetUid = targetUser?['uid'] ?? '';
          
          final senderUser2 = await _authService.getUserByMeshId(ip.senderMeshId);
          final senderUid2 = senderUser2?['uid'] ?? '';

          if (targetUid.isNotEmpty && senderUid2.isNotEmpty) {
            await _authService.sendMessageOnBehalf(
              senderUid2,
              targetUid,
              "Payment Request: ₹$amount",
              type: 'PAYMENT_REQUEST',
              metadata: {
                'amount': amount,
                'upiId': upiId,
                'note': note,
                'senderMeshId': ip.senderMeshId,
                'viaGateway': true,
              },
            );
            responseData = "SUCCESS";
          } else {
            status = "error";
            responseData = "Receiver or Sender not found";
          }
          break;
        default:
          status = "error";
          responseData = "Service not implemented";
      }
    } catch (e) {
      status = "error";
      responseData = e.toString();
    }

    _sendInternetResponse(ip.senderMeshId, endpointId, ip.requestId, status, responseData);
  }

  void _sendInternetResponse(String targetMeshId, String endpointId, String requestId, String status, String data) async {
    final profile = await getUserProfile();
    final myMeshId = profile?['meshId'] ?? 'Gateway';

    Map<String, dynamic> respPayload = {
      'requestId': requestId,
      'status': status,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    MeshPacket packet = MeshPacket(
      senderMeshId: myMeshId,
      destinationMeshId: targetMeshId,
      payload: jsonEncode(respPayload),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: MeshPacketType.internetResponse,
      ttl: 3,
    );

    Uint8List bytes = Uint8List.fromList(utf8.encode(packet.serialize()));
    Nearby().sendBytesPayload(endpointId, bytes);
  }

  void _endGatewaySession() {
    if (_activeSession == null) return;

    _log("Ending gateway session for ${_activeSession!.senderMeshId}");
    
    _activeSession!.status = GatewayRequestStatus.completed;
    _requestQueue.removeAt(0);
    _activeSession = null;
    
    _sessionController.add(null);
    _queueController.add(_requestQueue);

    _processNextRequest();
  }

  void _startRoutingReplies(String friendUid, String senderMeshId, String senderEndpointId) {
    String subKey = "${friendUid}_$senderMeshId";
    if (_routingSubs.containsKey(subKey)) return;

    _log("[GATEWAY] Routing replies for $senderMeshId from online friend $friendUid");

    // Track the last processed message timestamp to only route NEW messages
    int lastTimestamp = DateTime.now().millisecondsSinceEpoch;

    _routingSubs[subKey] = _authService.messagesStream(friendUid).listen((messages) {
      if (messages.isEmpty) return;
      
      // Filter for messages from the friend received AFTER we started routing
      final newMessages = messages.where((m) {
        final ts = m['timestamp'] ?? 0;
        return m['senderId'] == friendUid && ts > lastTimestamp;
      }).toList();

      for (var msg in newMessages) {
        lastTimestamp = msg['timestamp'] ?? lastTimestamp;
        receiveIncomingGatewayMessage({
          'receiverMeshId': senderMeshId,
          'friendUid': friendUid,
          'message': msg['text'] ?? '',
        });
      }
    });
  }

  /// Called when backend sends a message for a mesh user to this gateway
  Future<void> receiveIncomingGatewayMessage(Map<String, dynamic> data) async {
    final String targetMeshId = data['receiverMeshId'] ?? '';
    final String message = data['message'] ?? '';
    final String friendUid = data['friendUid'] ?? '';
    
    if (targetMeshId.isEmpty) return;

    _log("[GATEWAY] Routing backend response to $targetMeshId");

    // Find if user is in our connected peers
    String? endpointId;
    connectedPeers.forEach((eid, node) {
      if (node.meshId == targetMeshId) endpointId = eid;
    });

    if (endpointId != null) {
      final profile = await getUserProfile();
      final myMeshId = profile?['meshId'] ?? 'Gateway';

      Map<String, dynamic> payload = {
        'type': 'INTERNET_RESPONSE',
        'receiverMeshId': targetMeshId,
        'friendUid': friendUid,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      MeshPacket packet = MeshPacket(
        senderMeshId: myMeshId,
        destinationMeshId: targetMeshId,
        payload: jsonEncode(payload),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: MeshPacketType.internetResponse,
        ttl: 1,
      );

      Uint8List bytes = Uint8List.fromList(utf8.encode(packet.serialize()));
      await Nearby().sendBytesPayload(endpointId!, bytes);
    } else {
      _log("[GATEWAY] Target $targetMeshId not nearby, dropping backend response.");
    }
  }

  void _handleInternetResponse(MeshPacket packet) {
    _packetStreamController.add(packet);
    _log("Internet request RESPONSE: ${packet.payload}");
  }

  Future<void> requestInternetAccess(String gatewayEndpointId) async {
    final profile = await _authService.getUserProfile();
    final myMeshId = profile?['meshId'] ?? 'Client';

    MeshPacket request = MeshPacket(
      senderMeshId: myMeshId,
      payload: "INTERNET_REQUEST",
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: MeshPacketType.internetRequest,
      ttl: 1,
    );

    Uint8List bytes = Uint8List.fromList(utf8.encode(request.serialize()));
    await Nearby().sendBytesPayload(gatewayEndpointId, bytes);
  }

  void _handleNotifications(MeshPacket packet) async {
    // If we are currently chatting with this person in the foreground, don't show notification
    if (NotificationService.activeChatMeshId == packet.senderMeshId) {
      return;
    }

    final senderName = packet.metadata?['senderName'] ?? 'Nearby User';

    switch (packet.type) {
      case MeshPacketType.message:
        NotificationService.showMessageNotification(
          senderName,
          packet.payload,
          packetId: packet.packetId,
          senderMeshId: packet.senderMeshId,
        );
        break;
      case MeshPacketType.paymentRequest:
        String amount = "Requested Payment";
        if (packet.payload.contains(": ")) {
           amount = packet.payload.split(": ")[1].split(" for ")[0];
        }
        NotificationService.showPaymentNotification(
          senderName,
          amount,
          paymentId: packet.packetId,
        );
        break;
      case MeshPacketType.broadcast:
      case MeshPacketType.sos:
        NotificationService.showBroadcastNotification(
          senderName,
          packet.payload,
          packetId: packet.packetId,
        );
        break;
      case MeshPacketType.internetResponse:
        try {
          final data = jsonDecode(packet.payload);
          if (data['type'] == 'INTERNET_RESPONSE') {
            final receiverMeshId = data['receiverMeshId'];
            final msg = data['message'] ?? '';
            // If it's a message for us forwarded from gateway
            if (await _isMyMeshId(receiverMeshId)) {
               NotificationService.showMessageNotification(
                 "Internet Bridge",
                 msg,
                 packetId: packet.packetId,
                 senderMeshId: packet.senderMeshId, // The gateway
               );
            }
          }
        } catch (_) {}
        break;
      default:
        break;
    }
  }
}
