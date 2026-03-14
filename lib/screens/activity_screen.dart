import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crowd_link/providers/mesh_provider.dart';
import 'package:crowd_link/providers/activity_provider.dart';
import 'package:crowd_link/models/mesh_packet.dart';
import 'package:crowd_link/models/payment_request.dart';
import 'package:crowd_link/screens/chat_screen.dart';
import 'package:crowd_link/screens/broadcast_chat_screen.dart';
import 'package:crowd_link/services/mesh_service.dart';
import 'package:crowd_link/components/payment_request_card.dart';
import 'package:crowd_link/models/internet_packet.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityProvider>(
      builder: (context, activityProvider, child) {
        final activities = activityProvider.activities;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Activity History', style: TextStyle(fontSize: 28, fontWeight: FontWeight.normal)),
          ),
          body: activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       const Icon(Icons.history_rounded, size: 64, color: Colors.white10),
                       const SizedBox(height: 16),
                       const Text("No recent activity", style: TextStyle(color: Colors.white24)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    final packet = activities[index];
                    return _ActivityTile(packet: packet);
                  },
                ),
        );
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final MeshPacket packet;
  const _ActivityTile({required this.packet});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(packet.timestamp));
    
    IconData icon;
    Color iconColor;
    String title;
    String subtitle;
    String senderName = packet.metadata?['senderName'] ?? 'Device';

    switch (packet.type) {
      case MeshPacketType.broadcast:
        icon = Icons.campaign_rounded;
        iconColor = Colors.orangeAccent;
        title = "Broadcast from $senderName";
        subtitle = packet.payload;
        break;
      case MeshPacketType.sos:
        icon = Icons.sos_rounded;
        iconColor = Colors.redAccent;
        title = "SOS Alert from $senderName";
        subtitle = packet.payload;
        break;
      case MeshPacketType.paymentRequest:
        icon = Icons.payments_rounded;
        iconColor = const Color(0xFF00FC82);
        title = "Payment Request";
        final amount = packet.metadata?['amount'] ?? '0';
        final note = packet.metadata?['note'] ?? packet.metadata?['reason'] ?? 'Mesh Payment';
        subtitle = "₹$amount • $note";
        break;
      case MeshPacketType.internetResponse:
        icon = Icons.cloud_done_rounded;
        iconColor = Colors.lightBlueAccent;
        try {
          final data = jsonDecode(packet.payload);
          if (data['type'] == 'INTERNET_RESPONSE') {
            title = "Message via Gateway";
            subtitle = data['message'] ?? 'New Message';
          } else {
            title = "Gateway Update";
            subtitle = data['status'] == 'error' ? "Delivery Failed" : "Request Success";
          }
        } catch (e) {
          title = "Gateway Activity";
          subtitle = "Processing request...";
        }
        break;
      case MeshPacketType.internetRequest:
        icon = Icons.account_balance_wallet_rounded;
        iconColor = const Color(0xFF00FC82);
        try {
          final ip = InternetPacket.fromJson(jsonDecode(packet.payload));
          if (ip.serviceType == InternetServiceType.upiPayment) {
            title = "Mesh Payment Request";
            subtitle = "From $senderName to ${ip.payload['upiId']}\n₹${ip.payload['amount']}";
          } else {
            title = "Internet Request";
            subtitle = "${ip.serviceType.name.toUpperCase()} request";
          }
        } catch (e) {
          title = "Internet Request";
          subtitle = "Service Request from $senderName";
        }
        break;
      case MeshPacketType.paymentConfirmation:
        icon = Icons.check_circle_rounded;
        iconColor = const Color(0xFF00FC82);
        title = "Payment Confirmed";
        subtitle = "From $senderName: ${packet.payload}";
        break;
      default:
        icon = Icons.chat_bubble_rounded;
        iconColor = Theme.of(context).colorScheme.primary;
        title = "Message from $senderName";
        subtitle = packet.payload;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _handleTap(context, packet),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: TextStyle(color: iconColor, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(time, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.3),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, MeshPacket packet) {
    if (packet.type == MeshPacketType.broadcast || packet.type == MeshPacketType.sos) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BroadcastChatScreen()));
    } else if (packet.type == MeshPacketType.paymentRequest || packet.type == MeshPacketType.internetRequest) {
      if (packet.type == MeshPacketType.internetRequest) {
        try {
          final ip = InternetPacket.fromJson(jsonDecode(packet.payload));
          if (ip.serviceType == InternetServiceType.upiPayment) {
            _showInternetPaymentPopup(context, packet, ip);
            return;
          }
        } catch (e) {
          // Fallback or ignore
        }
      }
      _showPaymentPopup(context, packet);
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatWindowScreen(
          friendUid: '', 
          friendName: packet.metadata?['senderName'] ?? 'Device',
          friendMeshId: packet.senderMeshId,
        ),
      ));
    }
  }

  void _showPaymentPopup(BuildContext context, MeshPacket packet) {
    final senderName = packet.metadata?['senderName'] ?? packet.metadata?['senderMeshId'] ?? packet.senderMeshId;
    final amount = packet.metadata?['amount'] ?? '0';
    final upiId = packet.metadata?['upiId'] ?? 'merchant@upi';
    final note = packet.metadata?['note'] ?? packet.metadata?['reason'] ?? 'Mesh Payment';

    PaymentRequestCard.showDetailsDialog(
      context: context,
      senderName: senderName,
      amount: amount.toString(),
      note: note,
      upiId: upiId,
      isMine: false,
      onPay: () => _launchUPI(upiId, senderName, amount.toString(), note),
      onReject: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Ignored"))),
    );
  }

  void _showInternetPaymentPopup(BuildContext context, MeshPacket packet, InternetPacket ip) {
    final senderName = packet.metadata?['senderName'] ?? packet.senderMeshId;
    final amount = ip.payload['amount'] ?? '0';
    final upiId = ip.payload['upiId'] ?? 'merchant@upi';
    final note = ip.payload['note'] ?? 'Mesh Payment';

    PaymentRequestCard.showDetailsDialog(
      context: context,
      senderName: senderName,
      amount: amount.toString(),
      note: note,
      upiId: upiId,
      isMine: false,
      onPay: () => _launchUPI(upiId, senderName, amount, note),
      onReject: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Ignored"))),
    );
  }

  void _launchUPI(String upiId, String name, String amount, String note) async {
    final upiUrl = "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(name)}&am=$amount&cu=INR&tn=${Uri.encodeComponent(note)}";
    final uri = Uri.parse(upiUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint("Could not launch UPI URL: $upiUrl");
    }
  }
}
