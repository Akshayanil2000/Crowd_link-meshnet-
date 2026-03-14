import 'package:flutter/material.dart';
import 'package:crowd_link/services/auth_service.dart';
// Removed import '../main.dart' as it's no longer needed for authService

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _loading = false;
  bool _obscure = true;

  // Login fields
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();

  // Register fields
  final _regName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPass = TextEditingController();
  final _regPass2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose(); _loginPass.dispose();
    _regName.dispose(); _regEmail.dispose(); _regPass.dispose(); _regPass2.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _login() async {
    if (_loginEmail.text.isEmpty || _loginPass.text.isEmpty) {
      return _showError('Please fill all fields');
    }
    setState(() => _loading = true);
    final err = await AuthService().signIn(email: _loginEmail.text.trim(), password: _loginPass.text.trim());
    setState(() => _loading = false);
    if (err != null) _showError(err);
    else if (mounted) Navigator.pop(context);
  }

  Future<void> _register() async {
    if (_regName.text.isEmpty || _regEmail.text.isEmpty || _regPass.text.isEmpty) {
      return _showError('Please fill all fields');
    }
    if (_regPass.text != _regPass2.text) return _showError('Passwords do not match');
    if (_regPass.text.length < 6) return _showError('Password must be at least 6 characters');
    setState(() => _loading = true);
    final err = await AuthService().register(
      email: _regEmail.text.trim(),
      password: _regPass.text.trim(),
      name: _regName.text.trim(),
    );
    setState(() => _loading = false);
    if (err != null) _showError(err);
    else if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.hub_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Text('CrowdLink', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in to access friends and\nreal-time mesh messaging.',
                style: const TextStyle(color: Colors.white54, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 36),

              // Tab bar
              Container(
                decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(14)),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [Tab(text: 'Sign In'), Tab(text: 'Register')],
                ),
              ),
              const SizedBox(height: 28),

              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    // ── Sign In ──
                    _buildLoginForm(),
                    // ── Register ──
                    _buildRegisterForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _field(_loginEmail, 'Email', Icons.email_outlined, TextInputType.emailAddress),
          const SizedBox(height: 14),
          _passField(_loginPass, 'Password'),
          const SizedBox(height: 28),
          _submitButton('Sign In', _login),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _field(_regName, 'Display Name', Icons.person_outline),
          const SizedBox(height: 14),
          _field(_regEmail, 'Email', Icons.email_outlined, TextInputType.emailAddress),
          const SizedBox(height: 14),
          _passField(_regPass, 'Password'),
          const SizedBox(height: 14),
          _passField(_regPass2, 'Confirm Password'),
          const SizedBox(height: 28),
          _submitButton('Create Account & Get Mesh ID', _register),
          const SizedBox(height: 16),
          const Text(
            'A unique Mesh ID (e.g. MN-A3F9K2) will be generated for you automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon, [TextInputType? type]) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: const Color(0xFF141414),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _passField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      obscureText: _obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white38, size: 20),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: const Color(0xFF141414),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _submitButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }
}
