enum InternetServiceType {
  httpGet,
  httpPost,
  apiCall,
  upiPayment,
  otpVerify,
  smsSend,
  sendMessage,
}

class InternetPacket {
  final String requestId;
  final String senderMeshId;
  final InternetServiceType serviceType;
  final Map<String, dynamic> payload;
  final int timestamp;

  InternetPacket({
    required this.requestId,
    required this.senderMeshId,
    required this.serviceType,
    required this.payload,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'senderMeshId': senderMeshId,
    'serviceType': serviceType.index,
    'payload': payload,
    'timestamp': timestamp,
  };

  factory InternetPacket.fromJson(Map<String, dynamic> json) => InternetPacket(
    requestId: json['requestId'],
    senderMeshId: json['senderMeshId'],
    serviceType: InternetServiceType.values[json['serviceType']],
    payload: Map<String, dynamic>.from(json['payload']),
    timestamp: json['timestamp'],
  );
}
