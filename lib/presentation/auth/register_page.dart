import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/api/auth_api.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _campus = TextEditingController();
  bool _loading = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre completo')),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Password (mín. 6)'), obscureText: true),
            TextField(controller: _campus, decoration: const InputDecoration(labelText: 'Campus (opcional)')),
            const SizedBox(height: 12),
            if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Creando…' : 'Registrarme'),
            ),
            TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/login'); // ✅ evita “There is nothing to pop”
                      }
                    },
              child: const Text('Ya tengo cuenta'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pass = _pass.text;
    final campus = _campus.text.trim().isEmpty ? null : _campus.text.trim();

    if (name.isEmpty || email.isEmpty || pass.length < 6) {
      setState(() => _err = 'Completa nombre, email y una contraseña de 6+ caracteres.');
      return;
    }

    setState(() {
      _loading = true;
      _err = null;
    });

    final api = AuthApi();
    try {
      await api.register(name: name, email: email, password: pass, campus: campus);
      await api.login(email: email, password: pass); // login automático
      if (mounted) context.go('/'); // ✅ entra al Home
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
