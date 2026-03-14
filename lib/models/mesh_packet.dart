import 'dart:convert';
import 'package:uuid/uuid.dart';

enum MeshPacketType {
  message,
  broadcast,
  sos,
  heartbeat,
  gatewayAnnouncement,
  internetRequest,
  internetResponse,
  paymentRequest,
  paymentConfirmation,
}

class MeshPacket {
  final String packetId;
  final String senderMeshId;
  final String? destinationMeshId; // Null for broadcast/sos
  final String payload;
  final int timestamp;
  int ttl;
  final MeshPacketType type;
  final Map<String, dynamic>? metadata;

  MeshPacket({
    String? packetId,
    required this.senderMeshId,
    this.destinationMeshId,
    required this.payload,
    required this.timestamp,
    this.ttl = 3, // Default hop limit
    required this.type,
    this.metadata,
  }) : packetId = packetId ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'packetId': packetId,
        'senderMeshId': senderMeshId,
        'destinationMeshId': destinationMeshId,
        'payload': payload,
        'timestamp': timestamp,
        'ttl': ttl,
        'type': type.index,
        'metadata': metadata,
      };

  factory MeshPacket.fromJson(Map<String, dynamic> json) => MeshPacket(
        packetId: json['packetId'],
        senderMeshId: json['senderMeshId'],
        destinationMeshId: json['destinationMeshId'],
        payload: json['payload'],
        timestamp: json['timestamp'],
        ttl: json['ttl'],
        type: MeshPacketType.values[json['type']],
        metadata: json['metadata'],
      );

  String serialize() => jsonEncode(toJson());

  factory MeshPacket.deserialize(String data) =>
      MeshPacket.fromJson(jsonDecode(data));
}
