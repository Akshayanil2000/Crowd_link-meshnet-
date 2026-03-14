import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:crowd_link/screens/chat_screen.dart';
import 'package:crowd_link/screens/activity_screen.dart';
import 'package:crowd_link/screens/broadcast_chat_screen.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static const String meshStatusChannelId = 'mesh_status_channel';
  static const String messageChannelId = 'message_channel';
  static const String paymentChannelId = 'payment_channel';

  static final Set<String> _shownNotificationIds = {};
  
  /// Tracks the mesh ID of the user currently being chatted with in the foreground.
  static String? activeChatMeshId;

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payloadRaw = response.payload;
        if (payloadRaw == null) return;

        try {
          final Map<String, dynamic> payload = jsonDecode(payloadRaw);
          final type = payload['type'];

          if (type == 'chat') {
            final meshId = payload['friendId'];
            final name = payload['friendName'] ?? 'Friend';
            final uid = payload['friendUid'] ?? '';
            
            navigatorKey.currentState?.push(MaterialPageRoute(
              builder: (_) => ChatWindowScreen(
                friendUid: uid,
                friendName: name,
                friendMeshId: meshId
              ),
            ));
          } else if (type == 'payment') {
            navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const ActivityScreen()));
          } else if (type == 'broadcast') {
            navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const BroadcastChatScreen()));
          }
        } catch (e) {
          debugPrint("Notification tap error: $e");
        }
      },
    );

    // Create Android Channels
    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        meshStatusChannelId,
        'Mesh Network Status',
        description: 'Ongoing status of the local mesh network',
        importance: Importance.low,
      ));

      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        messageChannelId,
        'Messages',
        description: 'New chat messages from friends',
        importance: Importance.max,
        playSound: true,
      ));

      await androidImplementation.createNotificationChannel(const AndroidNotificationChannel(
        paymentChannelId,
        'Payment Requests',
        description: 'New payment requests and confirmations',
        importance: Importance.max,
        playSound: true,
      ));
    }
  }

  static Future<void> showMeshStatus(bool active, String status) async {
    if (!active) {
      await _notificationsPlugin.cancel(100);
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      meshStatusChannelId,
      'Mesh Network Status',
      channelDescription: 'Ongoing status of the local mesh network',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      100,
      'Mesh Network Active',
      status,
      notificationDetails,
    );
  }

  static Future<void> showMessageNotification(String senderName, String message, {String? packetId, String? senderMeshId, String? friendUid}) async {
    if (packetId != null && _shownNotificationIds.contains(packetId)) return;
    if (packetId != null) _shownNotificationIds.add(packetId);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      messageChannelId,
      'Messages',
      channelDescription: 'New chat messages from friends',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecond + 1000,
      senderName,
      message,
      notificationDetails,
      payload: jsonEncode({
        'type': 'chat',
        'friendId': senderMeshId,
        'friendName': senderName,
        'friendUid': friendUid ?? '',
      }),
    );
  }

  static Future<void> showPaymentNotification(String senderName, String amount, {String? paymentId}) async {
    if (paymentId != null && _shownNotificationIds.contains(paymentId)) return;
    if (paymentId != null) _shownNotificationIds.add(paymentId);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      paymentChannelId,
      'Payment Requests',
      channelDescription: 'New payment requests and confirmations',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecond + 2000,
      'Payment Request',
      '$senderName requested ₹$amount',
      notificationDetails,
      payload: jsonEncode({
        'type': 'payment',
        'paymentId': paymentId ?? '',
      }),
    );
  }

  static Future<void> showBroadcastNotification(String senderName, String message, {String? packetId}) async {
    if (packetId != null && _shownNotificationIds.contains(packetId)) return;
    if (packetId != null) _shownNotificationIds.add(packetId);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      messageChannelId,
      'Broadcast Alert',
      channelDescription: 'Public messages in the mesh network',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecond + 3000,
      'Public Message from $senderName',
      message,
      notificationDetails,
      payload: jsonEncode({
        'type': 'broadcast'
      }),
    );
  }
}
