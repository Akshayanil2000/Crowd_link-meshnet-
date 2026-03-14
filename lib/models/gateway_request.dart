import 'internet_packet.dart';

enum GatewayRequestStatus {
  waiting,
  approved,
  active,
  completed,
  denied
}

class GatewayRequest {
  final String requestId;
  final String senderMeshId;
  final String endpointId;
  final int timestamp;
  GatewayRequestStatus status;
  final InternetPacket? internetPacket;

  GatewayRequest({
    required this.requestId,
    required this.senderMeshId,
    required this.endpointId,
    required this.timestamp,
    this.status = GatewayRequestStatus.waiting,
    this.internetPacket,
  });

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'senderMeshId': senderMeshId,
    'endpointId': endpointId,
    'timestamp': timestamp,
    'status': status.index,
  };

  factory GatewayRequest.fromJson(Map<String, dynamic> json) => GatewayRequest(
    requestId: json['requestId'],
    senderMeshId: json['senderMeshId'],
    endpointId: json['endpointId'],
    timestamp: json['timestamp'],
    status: GatewayRequestStatus.values[json['status']],
  );
}
