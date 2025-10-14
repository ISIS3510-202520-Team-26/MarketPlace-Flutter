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
  bool _hidePass = true;

  // Colores inspirados en la vista
  static const Color _bg = Color(0xFFF1EEF3);      // fondo exterior
  static const Color _panel = Color(0xFFE9E3EA);   // tarjeta suave
  static const Color _green = Color(0xFF0E4F3F);   // botón / títulos
  static const Color _hint = Color(0xFF9BA0A5);    // placehoders

  InputDecoration _pillDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hint, fontSize: 16),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(color: _green.withOpacity(0.5), width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Título
                    const Text(
                      '¡Hola! Regístrate para\nempezar.',
                      style: TextStyle(
                        color: _green,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Campos
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: _pillDecoration('Nombre completo'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _pillDecoration('Email'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pass,
                      obscureText: _hidePass,
                      textInputAction: TextInputAction.done,
                      decoration: _pillDecoration('Password (mín. 6)').copyWith(
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidePass = !_hidePass),
                          icon: Icon(_hidePass ? Icons.visibility_off : Icons.visibility),
                          color: _hint,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _campus,
                      decoration: _pillDecoration('Campus (opcional)'),
                    ),

                    // Error
                    if (_err != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _err!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Botón principal
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(_loading ? 'Creando…' : 'Registrarme'),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Separador "O registrarse con"
                    Row(
                      children: [
                        const Expanded(child: Divider(height: 1, color: Color(0xFFDBD7DE))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('O regístrate con',
                              style: TextStyle(color: Colors.grey.shade700)),
                        ),
                        const Expanded(child: Divider(height: 1, color: Color(0xFFDBD7DE))),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Botones sociales (solo UI / placeholders)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: const [
                        _SocialBox(label: 'f'),
                        _SocialBox(label: 'G'),
                        _SocialBox(label: 'A'),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Link "Ya tengo cuenta"
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('¿Ya tienes cuenta? ',
                              style: TextStyle(color: Colors.grey.shade700)),
                          InkWell(
                            onTap: _loading
                                ? null
                                : () {
                                    if (context.canPop()) {
                                      context.pop();
                                    } else {
                                      context.go('/login'); // evita “There is nothing to pop”
                                    }
                                  },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              child: Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                  color: _green,
                                  fontWeight: FontWeight.w800,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =======================
  // LÓGICA: SIN CAMBIOS
  // =======================
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
      if (mounted) context.go('/'); // entra al Home
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _SocialBox extends StatelessWidget {
  const _SocialBox({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3DEE6)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _RegisterPageState._green),
      ),
    );
  }
}
