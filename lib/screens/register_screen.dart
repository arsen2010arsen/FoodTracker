import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = _messageFromCode(e.code));
    } catch (_) {
      setState(() => _errorText = 'Не вдалося створити акаунт.');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _messageFromCode(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Цей email вже використовується.';
      case 'weak-password':
        return 'Пароль занадто слабкий (мінімум 6 символів).';
      case 'invalid-email':
        return 'Некоректний формат email.';
      default:
        return 'Помилка реєстрації. Спробуйте ще раз.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Реєстрація')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Вкажіть email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Пароль'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Вкажіть пароль';
                        if (v.trim().length < 6) return 'Мінімум 6 символів';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Підтвердіть пароль'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Повторіть пароль';
                        }
                        if (v.trim() != _passwordController.text.trim()) {
                          return 'Паролі не співпадають';
                        }
                        return null;
                      },
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 10),
                      Text(_errorText!, style: const TextStyle(color: Colors.redAccent)),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _isLoading ? null : _register,
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Зареєструватися'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ми поважаємо вашу приватність. Ваші дані зашифровані та доступні тільки вам. Паролі зберігаються на захищених серверах Google Firebase і не доступні розробнику.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                          ),
                      textAlign: TextAlign.center,
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
}
