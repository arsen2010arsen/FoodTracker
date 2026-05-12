import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';

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
      appBar: AppBar(
        title: const Text('Реєстрація'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header icon ──────────────────────
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 30,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Email ────────────────────────────
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Вкажіть email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── Password ─────────────────────────
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Вкажіть пароль';
                        if (v.trim().length < 6) return 'Мінімум 6 символів';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // ── Confirm password ─────────────────
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Підтвердіть пароль',
                        prefixIcon:
                            Icon(Icons.lock_outline_rounded, size: 20),
                      ),
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

                    // ── Error ────────────────────────────
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.fats.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _errorText!,
                          style: TextStyle(
                            color: AppColors.fats,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),

                    // ── Register button ──────────────────
                    _RegisterGradientButton(
                      onPressed: _isLoading ? null : _register,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 16),

                    // ── Privacy note ─────────────────────
                    Text(
                      'Ми поважаємо вашу приватність. Ваші дані зашифровані та доступні тільки вам. Паролі зберігаються на захищених серверах Google Firebase і не доступні розробнику.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white30,
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

// ═══════════════════════════════════════════════════════════════════
// ─── Register Gradient Button ─────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

class _RegisterGradientButton extends StatefulWidget {
  const _RegisterGradientButton({
    required this.onPressed,
    required this.isLoading,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  State<_RegisterGradientButton> createState() =>
      _RegisterGradientButtonState();
}

class _RegisterGradientButtonState extends State<_RegisterGradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed!();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryStart.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Зареєструватися',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
