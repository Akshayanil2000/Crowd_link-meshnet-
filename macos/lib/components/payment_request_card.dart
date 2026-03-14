import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentRequestCard extends StatelessWidget {
  final String senderName;
  final String amount;
  final String note;
  final String upiId;
  final bool isMine;
  final VoidCallback? onPay;
  final VoidCallback? onReject;

  const PaymentRequestCard({
    super.key,
    required this.senderName,
    required this.amount,
    required this.note,
    required this.upiId,
    required this.isMine,
    this.onPay,
    this.onReject,
  });

  static void showDetailsDialog({
    required BuildContext context,
    required String senderName,
    required String amount,
    required String note,
    required String upiId,
    required bool isMine,
    VoidCallback? onPay,
    VoidCallback? onReject,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF00FC82), width: 1),
        ),
        title: const Row(
          children: [
            Icon(Icons.payments_rounded, color: Color(0xFF00FC82)),
            SizedBox(width: 12),
            Text('Payment Request', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('From: $senderName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                const SizedBox(height: 8),
                Text('UPI ID: $upiId', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Note: $note', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const Divider(height: 32, color: Colors.white10),
                Center(
                  child: Text(
                    '₹$amount',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF00FC82)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          if (!isMine) ...[
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (onReject != null) onReject();
              },
              child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FC82),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (onPay != null) onPay();
              },
              child: const Text('Pay', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDetailsDialog(
        context: context,
        senderName: senderName,
        amount: amount,
        note: note,
        upiId: upiId,
        isMine: isMine,
        onPay: onPay,
        onReject: onReject,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.75,
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF1A1A1A) : const Color(0xFF242424),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF00FC82).withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FC82).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: Color(0xFF00FC82),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Payment Request',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF00FC82),
                    ),
                  ),
                ),
                Text(
                  'Tap for details',
                  style: TextStyle(
                    fontSize: 9, 
                    color: const Color(0xFF00FC82).withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'From: $senderName',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Amount: ₹$amount',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Note: $note',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            if (!isMine) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onPay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FC82),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Pay',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Reject',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Awaiting Payment...',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Colors.white24,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static void launchUPI(String upiId, String name, String amount, String note) async {
    final upiUrl = "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(name)}&am=$amount&cu=INR&tn=${Uri.encodeComponent(note)}";
    final uri = Uri.parse(upiUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
