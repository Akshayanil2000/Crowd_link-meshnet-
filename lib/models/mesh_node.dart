class MeshNode {
  final String endpointId;
  final String meshId;
  final String deviceName;
  final String username;
  final bool isGateway;
  double signalStrength;
  DateTime lastSeen;

  MeshNode({
    required this.endpointId,
    required this.meshId,
    required this.deviceName,
    required this.username,
    this.isGateway = false,
    this.signalStrength = 1.0,
    required this.lastSeen,
  });

  factory MeshNode.fromMetadata(String endpointId, String metadata, {double signal = 1.0}) {
    // metadata is "meshId|name" or "meshId|name|isGateway"
    final parts = metadata.split('|');
    return MeshNode(
      endpointId: endpointId,
      meshId: parts[0],
      deviceName: parts.length > 1 ? parts[1] : 'Unknown',
      username: parts.length > 1 ? parts[1] : 'Unknown',
      isGateway: parts.length > 2 ? parts[2].toLowerCase() == 'true' : false,
      signalStrength: signal,
      lastSeen: DateTime.now(),
    );
  }
}
