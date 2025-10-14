import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/api/auth_api.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _err;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _pass,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            if (_err != null) Text(_err!, style: const TextStyle(color: Colors.red)),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : () async {
                      setState(() {
                        _loading = true;
                        _err = null;
                      });
                      try {
                        await AuthApi().login(email: _email.text.trim(), password: _pass.text);
                        if (mounted) context.go('/'); // ✅ navega con GoRouter
                      } catch (e) {
                        setState(() => _err = '$e');
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
                    child: Text(_loading ? '...' : 'Entrar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loading ? null : () => context.push('/register'), // ✅ a Register
              child: const Text('¿No tienes cuenta? Crea una'),
            ),
          ],
        ),
      ),
    );
  }
}
