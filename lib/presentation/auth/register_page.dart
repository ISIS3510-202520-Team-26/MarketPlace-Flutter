// lib/presentation/auth/register_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/utils/input_formatters.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const _primary = Color(0xFF0F6E5D);

  final _authRepo = AuthRepository();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _campus = TextEditingController();

  bool _busy = false;
  bool _showPass = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    Telemetry.i.view('register');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _campus.dispose();
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
          'Registro',
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

          _textField(controller: _name, label: 'Nombre', hint: 'Tu nombre'),
          const SizedBox(height: 12),
          _textField(
            controller: _email,
            label: 'Email',
            hint: 't@uniandes.edu.co',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: !_showPass,
            maxLength: 40,
            inputFormatters: [NoConsecutiveSpecialCharsFormatter()],
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
          const SizedBox(height: 12),
          _textField(
            controller: _campus,
            label: 'Campus (opcional)',
            hint: 'Universidad de los Andes',
          ),

          const SizedBox(height: 24),
          _primaryButton(
            text: _busy ? 'Creando cuenta…' : 'Registrarme',
            onTap: _busy ? null : _submit,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Telemetry.i.click('go_to_login');
              context.push('/login');
            },
            child: const Text('¿Ya tienes cuenta? Inicia sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    final pass = _password.text;
    final campus = _campus.text.trim();

    // Validaciones locales alineadas con el backend
    final errors = <String>[];
    if (name.length < 2) errors.add('Nombre: mínimo 2 caracteres.');
    if (!_isValidEmail(email)) errors.add('Email no válido.');
    if (pass.length < 8) errors.add('Contraseña: mínimo 8 caracteres.');
    if (errors.isNotEmpty) {
      Telemetry.i.click('register_validation_failed', props: {'n': errors.length});
      setState(() => _err = errors.join('\n'));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _err = null;
    });

    Telemetry.i.click('register_submit', props: {
      'email_domain': _emailDomain(email),
      if (campus.isNotEmpty) 'campus': campus,
    });

    try {
      await _authRepo.register(
        name: name,
        email: email,
        password: pass,
        campus: campus.isEmpty ? null : campus,
      );

      Telemetry.i.click('register_result', props: {'ok': true});
      await Telemetry.i.flush();

      if (mounted) {
        // Si tu backend no hace autologin, manda al login:
        context.go('/login');
      }
    } catch (e) {
      Telemetry.i.click('register_result', props: {'ok': false});
      setState(() => _err = 'No se pudo registrar: $e');
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: 40,
      inputFormatters: [NoConsecutiveSpecialCharsFormatter()],
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

  // ---------- helpers validación ----------
  bool _isValidEmail(String s) {
    // Simple y suficiente para el backend
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(s);
  }

  String? _emailDomain(String s) {
    final i = s.indexOf('@');
    return i > 0 ? s.substring(i + 1) : null;
  }
}
