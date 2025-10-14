// lib/presentation/auth/login_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/auth_api.dart';
import '../../core/telemetry/telemetry.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _primary = Color(0xFF0F6E5D);

  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _showPass = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    Telemetry.i.view('login');
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Iniciar sesión',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_err != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_err!, style: const TextStyle(color: Colors.red)),
            ),

          _textField(
            controller: _email,
            label: 'Email',
            hint: 't@uniandes.edu.co',
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: !_showPass,
            onSubmitted: (_) => _submit(),
            decoration: _inputDecoration('Contraseña', hint: 'Mínimo 8 caracteres').copyWith(
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _showPass = !_showPass);
                  Telemetry.i.click('toggle_password', props: {'visible': _showPass});
                },
                icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, color: _primary),
              ),
            ),
          ),

          const SizedBox(height: 24),
          _primaryButton(
            text: _busy ? 'Entrando…' : 'Entrar',
            onTap: _busy ? null : _submit,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Telemetry.i.click('go_to_register');
              context.push('/register');
            },
            child: const Text('¿No tienes cuenta? Crear cuenta'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final email = _email.text.trim().toLowerCase();
    final pass = _password.text;

    // Validaciones locales para evitar 422 innecesarios
    final errors = <String>[];
    if (!_isValidEmail(email)) errors.add('Email no válido.');
    if (pass.length < 8) errors.add('Contraseña: mínimo 8 caracteres.');
    if (errors.isNotEmpty) {
      Telemetry.i.click('login_validation_failed', props: {'n': errors.length});
      setState(() => _err = errors.join('\n'));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _err = null;
    });

    Telemetry.i.click('login_submit', props: {'email_domain': _emailDomain(email)});

    try {
      await AuthApi().login(email: email, password: pass);
      Telemetry.i.click('login_result', props: {'ok': true});
      await Telemetry.i.flush();
      if (mounted) context.go('/'); // Home
    } catch (e) {
      Telemetry.i.click('login_result', props: {'ok': false});
      setState(() => _err = 'No se pudo iniciar sesión: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- UI helpers ----------
  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelStyle: const TextStyle(color: _primary, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: _primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      onSubmitted: onSubmitted,
      decoration: _inputDecoration(label, hint: hint),
    );
  }

  Widget _primaryButton({required String text, VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ---------- helpers ----------
  bool _isValidEmail(String s) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(s);
  }

  String? _emailDomain(String s) {
    final i = s.indexOf('@');
    return i > 0 ? s.substring(i + 1) : null;
    }
}
