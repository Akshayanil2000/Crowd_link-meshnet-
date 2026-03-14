import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crowd_link/models/payment_request.dart';
import 'package:crowd_link/models/mesh_packet.dart';
import 'package:crowd_link/models/internet_packet.dart';
import 'package:crowd_link/services/mesh_service.dart';

class ActivityProvider with ChangeNotifier {
  final List<PaymentRequest> _paymentRequests = [];
  final List<MeshPacket> _activities = [];

  List<PaymentRequest> get paymentRequests => _paymentRequests;
  List<MeshPacket> get activities => _activities;

  ActivityProvider(MeshService meshService) {
    meshService.messageStream.listen((packet) {
      if (packet.type == MeshPacketType.paymentRequest) {
        _handleMeshPaymentRequest(packet);
      } else if (packet.type == MeshPacketType.internetRequest) {
        _handleInternetPaymentRequest(packet);
      }
      
      // Prevent duplicates in activities list if needed (optional since we have packetId check in service)
      _activities.insert(0, packet);
      if (_activities.length > 100) _activities.removeLast();
      
      notifyListeners();
    });
  }

  void _handleMeshPaymentRequest(MeshPacket packet) {
    try {
      final amount = double.tryParse(packet.metadata?['amount'] ?? '0') ?? 0.0;
      final upiId = packet.metadata?['upiId'] ?? '';
      
      final req = PaymentRequest(
        paymentId: packet.packetId,
        senderMeshId: packet.senderMeshId,
        senderName: packet.metadata?['senderName'] ?? 'Unknown',
        upiId: upiId,
        amount: amount,
        note: packet.metadata?['reason'] ?? '',
        timestamp: packet.timestamp,
      );
      
      _addPaymentRequest(req);
    } catch (e) {
      debugPrint("Error handling mesh payment request: $e");
    }
  }

  void _handleInternetPaymentRequest(MeshPacket packet) {
    try {
      final ip = InternetPacket.fromJson(jsonDecode(packet.payload));
      if (ip.serviceType == InternetServiceType.upiPayment) {
        final req = PaymentRequest(
          paymentId: ip.requestId,
          senderMeshId: ip.senderMeshId,
          senderName: packet.metadata?['senderName'] ?? 'Unknown',
          upiId: ip.payload['upiId'] ?? '',
          amount: double.tryParse(ip.payload['amount'] ?? '0') ?? 0.0,
          note: ip.payload['note'] ?? '',
          timestamp: ip.timestamp,
        );
        _addPaymentRequest(req);
      }
    } catch (e) {
      debugPrint("Error handling internet payment request: $e");
    }
  }

  void _addPaymentRequest(PaymentRequest req) {
    if (!_paymentRequests.any((r) => r.paymentId == req.paymentId)) {
      _paymentRequests.insert(0, req);
    }
  }

  void updatePaymentStatus(String paymentId, PaymentStatus status) {
    final idx = _paymentRequests.indexWhere((r) => r.paymentId == paymentId);
    if (idx != -1) {
      _paymentRequests[idx].status = status;
      notifyListeners();
    }
  }
}
