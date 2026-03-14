import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:crowd_link/providers/mesh_provider.dart';
import 'package:crowd_link/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enableGateway = true;
  bool _requireApproval = true;
  int _sessionDuration = 60;
  bool _paymentFriendOnly = true;
  bool _smsFriendOnly = true;
  int _maxPayment = 500;
  int _maxSms = 160;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableGateway = prefs.getBool('enable_gateway') ?? true;
      _requireApproval = prefs.getBool('require_approval') ?? true;
      _sessionDuration = prefs.getInt('session_duration') ?? 60;
      _paymentFriendOnly = prefs.getBool('gateway_friend_only_upiPayment') ?? true;
      _smsFriendOnly = prefs.getBool('gateway_friend_only_smsSend') ?? true;
      _maxPayment = prefs.getInt('gateway_max_payment') ?? 500;
      _maxSms = prefs.getInt('gateway_max_sms') ?? 160;
      _loading = false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Internet Gateway'),
          SwitchListTile(
            title: const Text('Act as Gateway'),
            subtitle: const Text('Allow nearby nodes to share your internet connection'),
            value: _enableGateway,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (val) {
              setState(() => _enableGateway = val);
              _saveSetting('enable_gateway', val);
            },
          ),
          SwitchListTile(
            title: const Text('Require Approval'),
            subtitle: const Text('Show a prompt before sharing internet'),
            value: _requireApproval,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (val) {
              setState(() => _requireApproval = val);
              _saveSetting('require_approval', val);
            },
          ),
          ListTile(
            title: const Text('Session Duration'),
            subtitle: Text('$_sessionDuration seconds per request'),
            trailing: const Icon(Icons.timer_outlined),
            onTap: _showDurationPicker,
          ),
          
          const Divider(height: 40),
          _buildSectionHeader('Payment Security'),
          SwitchListTile(
            title: const Text('Friends Only'),
            subtitle: const Text('Allow payment requests only from trusted friends'),
            value: _paymentFriendOnly,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (val) {
              setState(() => _paymentFriendOnly = val);
              _saveSetting('gateway_friend_only_upiPayment', val);
            },
          ),
          ListTile(
            title: const Text('Max Payment Amount'),
            subtitle: Text('₹$_maxPayment limit per request'),
            trailing: const Icon(Icons.currency_rupee_rounded),
            onTap: () => _showIntPicker('Max Payment', 100, 2000, _maxPayment, (v) {
              setState(() => _maxPayment = v);
              _saveSetting('gateway_max_payment', v);
            }),
          ),
          
          const Divider(height: 40),
          _buildSectionHeader('SMS Gateway Security'),
          SwitchListTile(
            title: const Text('Friends Only'),
            subtitle: const Text('Allow SMS requests only from trusted friends'),
            value: _smsFriendOnly,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (val) {
              setState(() => _smsFriendOnly = val);
              _saveSetting('gateway_friend_only_smsSend', val);
            },
          ),
          ListTile(
            title: const Text('Max SMS Length'),
            subtitle: Text('$_maxSms characters limit'),
            trailing: const Icon(Icons.message_rounded),
            onTap: () => _showIntPicker('Max SMS Length', 50, 500, _maxSms, (v) {
              setState(() => _maxSms = v);
              _saveSetting('gateway_max_sms', v);
            }),
          ),
          
          const Divider(height: 40),
          _buildSectionHeader('Mesh Network'),
          ListTile(
            title: const Text('Mesh ID'),
            subtitle: const Text('Your unique identity on the network'),
            trailing: const Text('MN-A3F9K2', style: TextStyle(color: Colors.white38)), // Placeholder
          ),
          
          const Divider(height: 40),
          _buildSectionHeader('Info'),
          const AboutListTile(
            applicationName: 'CrowdLink',
            applicationVersion: '1.0.0',
            applicationIcon: Icon(Icons.hub_rounded),
          ),
          
          const Divider(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                await AuthService().signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              label: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showDurationPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session Limit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [30, 60, 120, 300].map((d) => RadioListTile<int>(
            title: Text('$d seconds'),
            value: d,
            groupValue: _sessionDuration,
            onChanged: (val) {
              if (val != null) {
                setState(() => _sessionDuration = val);
                _saveSetting('session_duration', val);
                Navigator.pop(ctx);
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showIntPicker(String title, int min, int max, int current, Function(int) onSelected) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [min, min * 2, current, max ~/ 2, max].toSet().where((i) => i >= min && i <= max).map((val) => ListTile(
              title: Text(val.toString()),
              onTap: () {
                onSelected(val);
                Navigator.pop(ctx);
              },
            )).toList(),
          ),
        ),
      ),
    );
  }
}
