import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logging/observability.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/secami_access.dart';
import '../../../core/theme/app_theme.dart';
import '../data/rest_auth_service.dart';

/// Login por usuário-ou-e-mail + senha: senha local do cadastro OU a do
/// governo (AD/LDAP, decidido no backend — SPEC §12).
/// Substitui o fluxo de e-mail/senha do Supabase quando `Env.hasRestApi`
/// (ver app_router.dart). Nome do arquivo é legado (era só LDAP antes).
class LdapSignInScreen extends ConsumerStatefulWidget {
  const LdapSignInScreen({super.key});

  @override
  ConsumerState<LdapSignInScreen> createState() => _LdapSignInScreenState();
}

class _LdapSignInScreenState extends ConsumerState<LdapSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
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
          .read(restAuthServiceProvider)
          .login(_userCtrl.text.trim(), _passwordCtrl.text);
      // Aguarda o provider resolver ANTES de navegar: um invalidate() sem
      // esperar deixa currentUserProvider momentaneamente null (loading),
      // e o redirect reativo do router bate de volta pra /sign-in antes
      // do go(...) "vencer" a corrida.
      final user = await ref.refresh(secamiCurrentUserProvider.future);
      await Observability.track('sign_in_success');
      if (!mounted) return;
      // Quem é só instrutor entra direto na Academia (alunos e fichas); os
      // demais, no diário de treinos — mesma regra do redirect do router.
      context.go(rotaInicialSecami(user));
    } catch (e, st) {
      await Observability.captureError(e, st, hint: 'ldap_sign_in');
      setState(() => _error = _humanize(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _EntranceFade(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Center(
                                child: Image.asset(
                                  'assets/branding/logo_casa_militar.png',
                                  width: 96,
                                  height: 96,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                              const SizedBox(height: AppTheme.space16),
                              Text(
                                'Academia SECAMI',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppTheme.space4),
                              Text(
                                'Casa Militar · Governo de Goiás',
                                style: AppTheme.label(
                                  12,
                                  color: scheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppTheme.space32),
                              Text(
                                'USUÁRIO OU E-MAIL',
                                style: AppTheme.label(
                                  11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppTheme.space8),
                              TextFormField(
                                controller: _userCtrl,
                                keyboardType: TextInputType.text,
                                autocorrect: false,
                                enableSuggestions: false,
                                textCapitalization: TextCapitalization.none,
                                autofillHints: const [AutofillHints.username],
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                                decoration: InputDecoration(
                                  hintText: 'usuário ou seu@email.com',
                                  prefixIcon: Icon(
                                    Icons.alternate_email,
                                    size: 20,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Informe o usuário ou e-mail'
                                    : null,
                              ),
                              const SizedBox(height: AppTheme.space16),
                              Text(
                                'SENHA',
                                style: AppTheme.label(
                                  11,
                                  color: scheme.onSurfaceVariant,
                                ),
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
                                    tooltip: _obscure
                                        ? 'Mostrar senha'
                                        : 'Ocultar senha',
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Informe a senha'
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
                                      : const Text(
                                          'ENTRAR',
                                          key: ValueKey('label'),
                                        ),
                                ),
                              ),
                              const SizedBox(height: AppTheme.space16),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Ainda não é aluno? ',
                                    style: AppTheme.label(
                                      12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 32),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => context.push('/cadastro'),
                                    child: const Text('Cadastre-se'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTheme.space8),
                              Text(
                                'Servidor(a) público(a)? Fale com a administração\n'
                                'da academia para receber seu acesso.',
                                style: AppTheme.label(
                                  11,
                                  color: scheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Fade + leve subida (12dp) na entrada da tela — feedback de que a tela
/// terminou de carregar, sem "bounce" (design-system.md §8).
class _EntranceFade extends StatelessWidget {
  const _EntranceFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppTheme.motionSlow,
      curve: AppTheme.easingStandard,
      builder: (context, t, childWidget) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: childWidget,
        ),
      ),
      child: child,
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
  // O backend já devolve mensagens finais em pt-BR pra login/cadastro
  // (inválido, cadastro em análise, cadastro recusado + motivo, inativo) —
  // repassa direto em vez de genericizar. Qualquer exceção que NÃO seja
  // ApiException (rede, JSON malformado etc.) nunca aparece como texto
  // técnico bruto pro usuário.
  if (e is! ApiException) {
    return 'Não foi possível entrar agora. Tente de novo em instantes.';
  }
  final msg = e.message.trim();
  if (msg.isEmpty || msg.length > 200) {
    return 'Não foi possível entrar agora. Tente de novo em instantes.';
  }
  return msg;
}
