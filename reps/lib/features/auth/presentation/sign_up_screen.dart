import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/logging/observability.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_service.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final auth = ref.read(authServiceProvider);
    if (!auth.isOnline) {
      setState(
        () => _error =
            'Backend não configurado. Preencha SUPABASE_URL e '
            'SUPABASE_ANON_KEY no arquivo .env e gere o app de novo. '
            'Sem isso, use o modo convidado.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        nome: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      );
      await Observability.track('account_created', {'provider': 'email'});
      if (!mounted) {
        return;
      }
      setState(() => _success = true);
    } on AuthException catch (e, st) {
      await Observability.captureError(e, st, hint: 'sign_up');
      // Detalhe do Supabase (signups desabilitados, senha fraca, API key
      // invalida...) fica só na telemetria acima — não vai pra tela.
      setState(
        () => _error =
            'Não foi possível criar a conta. Verifique os dados e tente novamente.',
      );
    } catch (e, st) {
      await Observability.captureError(e, st, hint: 'sign_up');
      setState(
        () => _error =
            'Não foi possível criar a conta agora. Tente novamente em instantes.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_success) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conta criada')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space24),
            child: Column(
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
                  'Conta criada',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.space8),
                Text(
                  'Verifique seu e-mail para confirmar o cadastro.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.space32),
                FilledButton(
                  onPressed: () => context.go('/routines'),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                  decoration: InputDecoration(
                    labelText: 'Nome (opcional)',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                TextFormField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: InputDecoration(
                    labelText: 'E-mail',
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
                TextFormField(
                  controller: _passwordCtrl,
                  focusNode: _passwordFocus,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Senha (min 8 caracteres)',
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 8)
                      ? 'Mínimo 8 caracteres'
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
                        : const Text('Criar conta', key: ValueKey('label')),
                  ),
                ),
                const SizedBox(height: AppTheme.space12),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/sign-in'),
                    child: const Text('Já tenho conta'),
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
