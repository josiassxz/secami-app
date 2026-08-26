import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/auth_service.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(authServiceProvider)
          .sendPasswordReset(_emailCtrl.text.trim());
      if (!mounted) {
        return;
      }
      setState(() => _sent = true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _sent = true); // por seguranca, nao revela se email existe
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar senha')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: _sent
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mark_email_read_outlined,
                          size: 32,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space24),
                    Text(
                      'Instruções enviadas',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Se houver conta com esse e-mail, você vai receber '
                      'instruções em alguns minutos.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.space32),
                    FilledButton(
                      onPressed: () => context.go('/sign-in'),
                      child: const Text('Voltar para entrar'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_reset_outlined,
                          size: 32,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space24),
                    Text(
                      'Esqueceu a senha?',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Informe o e-mail cadastrado e enviaremos instruções '
                      'para redefinir sua senha.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.space32),
                    Text(
                      'E-MAIL',
                      style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: 'voce@email.com',
                        prefixIcon: Icon(
                          Icons.mail_outline,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: AnimatedSwitcher(
                        duration: AppTheme.motionFast,
                        child: _loading
                            ? const SizedBox(
                                key: ValueKey('loading'),
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.onLimeAccent,
                                ),
                              )
                            : const Text(
                                'Enviar instruções',
                                key: ValueKey('label'),
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
