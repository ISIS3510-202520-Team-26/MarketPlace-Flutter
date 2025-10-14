import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/api/auth_api.dart';

// Colores (mismos de Register)
const Color kBg    = Color(0xFFF1EEF3);
const Color kPanel = Color(0xFFE9E3EA);
const Color kGreen = Color(0xFF0E4F3F);
const Color kHint  = Color(0xFF9BA0A5);

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
  bool _hidePass = true;

  InputDecoration _pillDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kHint, fontSize: 16),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: kGreen, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                decoration: BoxDecoration(
                  color: kPanel,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Welcome! Login to\nTech Market.',
                      style: TextStyle(
                        color: kGreen,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 22),

                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _pillDecoration('Enter your email'),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _pass,
                      obscureText: _hidePass,
                      textInputAction: TextInputAction.done,
                      decoration: _pillDecoration('Enter your password').copyWith(
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidePass = !_hidePass),
                          icon: Icon(_hidePass ? Icons.visibility_off : Icons.visibility),
                          color: kHint,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : () {}, // solo UI
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Forgot Password?'),
                      ),
                    ),

                    if (_err != null) ...[
                      Text(_err!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                    ],

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        child: Text(_loading ? '...' : 'Login'),
                      ),
                    ),

                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(child: Divider(height: 1, color: Color(0xFFDBD7DE))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('Or Login with', style: TextStyle(color: Colors.grey.shade700)),
                        ),
                        const Expanded(child: Divider(height: 1, color: Color(0xFFDBD7DE))),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: const [
                        _SocialBox(label: 'f'),
                        _SocialBox(label: 'G'),
                        _SocialBox(label: 'X'),
                      ],
                    ),

                    const SizedBox(height: 18),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text("Don't have an account? ",
                              style: TextStyle(color: Colors.grey.shade700)),
                          InkWell(
                            onTap: _loading ? null : () => context.push('/register'),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                              child: Text(
                                'Register Now',
                                style: TextStyle(
                                  color: kGreen,
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

  // ======= LÓGICA: igual que la tuya =======
  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      await AuthApi().login(email: _email.text.trim(), password: _pass.text);
      if (mounted) context.go('/');
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
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kGreen),
      ),
    );
  }
}
