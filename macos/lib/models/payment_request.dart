enum PaymentStatus {
  pending,
  approved,
  rejected,
  completed,
}

class PaymentRequest {
  final String paymentId;
  final String senderMeshId;
  final String senderName;
  final String upiId;
  final double amount;
  final String note;
  final int timestamp;
  PaymentStatus status;

  PaymentRequest({
    required this.paymentId,
    required this.senderMeshId,
    required this.senderName,
    required this.upiId,
    required this.amount,
    required this.note,
    required this.timestamp,
    this.status = PaymentStatus.pending,
  });

  Map<String, dynamic> toJson() => {
    'paymentId': paymentId,
    'senderMeshId': senderMeshId,
    'senderName': senderName,
    'upiId': upiId,
    'amount': amount,
    'note': note,
    'timestamp': timestamp,
    'status': status.index,
  };

  factory PaymentRequest.fromJson(Map<String, dynamic> json) => PaymentRequest(
    paymentId: json['paymentId'],
    senderMeshId: json['senderMeshId'],
    senderName: json['senderName'],
    upiId: json['upiId'],
    amount: (json['amount'] as num).toDouble(),
    note: json['note'],
    timestamp: json['timestamp'],
    status: PaymentStatus.values[json['status'] ?? 0],
  );
}
