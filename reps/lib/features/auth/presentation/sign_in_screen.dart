import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/observability.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_service.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .signIn(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      await Observability.track('sign_in_success');
      if (!mounted) return;
      context.go('/routines');
    } catch (e, st) {
      await Observability.captureError(e, st, hint: 'sign_in');
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bem-vindo\nde volta.',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: AppTheme.space32),
                Text(
                  'E-MAIL',
                  style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppTheme.space8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: InputDecoration(
                    hintText: 'voce@email.com',
                    prefixIcon: Icon(
                      Icons.mail_outline,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'E-mail invalido'
                      : null,
                ),
                const SizedBox(height: AppTheme.space16),
                Row(
                  children: [
                    Text(
                      'SENHA',
                      style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space8,
                        ),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      onPressed: () => context.go('/forgot-password'),
                      child: Text(
                        'esqueci',
                        style: AppTheme.label(11, color: scheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space8),
                TextFormField(
                  controller: _passwordCtrl,
                  focusNode: _passwordFocus,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Mínimo 6 caracteres'
                      : null,
                ),
                AnimatedSize(
                  duration: AppTheme.motionBase,
                  curve: AppTheme.easingStandard,
                  alignment: Alignment.topCenter,
                  child: _error == null
                      ? const SizedBox(height: AppTheme.space24)
                      : Padding(
                          padding: const EdgeInsets.only(
                            top: AppTheme.space24,
                            bottom: AppTheme.space12,
                          ),
                          child: _ErrorBanner(message: _error!),
                        ),
                ),
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
                        : const Text('ENTRAR', key: ValueKey('label')),
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/sign-up'),
                    child: Text(
                      'Não tenho conta',
                      style: AppTheme.label(12, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.15),
        border: Border.all(color: scheme.error),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.error),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _humanize(Object e) {
  final msg = e.toString();
  if (msg.contains('Invalid login credentials')) {
    return 'E-mail ou senha incorretos.';
  }
  if (msg.contains('not configured')) {
    return 'Supabase não configurado. Verifique o .env.';
  }
  return 'Não foi possível entrar agora. Tente de novo em instantes.';
}
