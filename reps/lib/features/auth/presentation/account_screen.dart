import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/logging/observability.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_providers.dart';
import '../../../core/network/erro_amigavel.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaAtualCtrl = TextEditingController();
  final _senhaNovaCtrl = TextEditingController();

  bool _savingNome = false;
  bool _savingEmail = false;
  bool _savingSenha = false;
  String? _nomeInicial;
  String? _emailInicial;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nomeInicial =
        (user?.userMetadata?['nome'] as String?) ??
        (user?.userMetadata?['full_name'] as String?) ??
        '';
    _emailInicial = user?.email ?? '';
    _nomeCtrl.text = _nomeInicial ?? '';
    _emailCtrl.text = _emailInicial ?? '';
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaAtualCtrl.dispose();
    _senhaNovaCtrl.dispose();
    super.dispose();
  }

  SupabaseClient _requireClient(BuildContext context) {
    final client = SupabaseConfig.clientOrNull;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supabase não configurado.')),
      );
      throw StateError('supabase_required');
    }
    return client;
  }

  Future<void> _salvarNome() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty || nome == _nomeInicial) return;
    setState(() => _savingNome = true);
    try {
      final client = _requireClient(context);
      await client.auth.updateUser(UserAttributes(data: {'nome': nome}));
      // Tambem atualiza coluna users.nome para refletir no Postgres.
      final uid = client.auth.currentUser?.id;
      if (uid != null) {
        await client.from('users').update({'nome': nome}).eq('id', uid);
      }
      await Observability.track('account_name_updated');
      _nomeInicial = nome;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nome atualizado.')));
    } on Object catch (e, st) {
      await Observability.captureError(e, st, hint: 'update_name');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensagemDeErro(
              e,
              fallback: 'Não foi possível salvar. Tente novamente.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingNome = false);
    }
  }

  Future<void> _salvarEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || email == _emailInicial) return;
    setState(() => _savingEmail = true);
    try {
      final client = _requireClient(context);
      await client.auth.updateUser(
        UserAttributes(email: email),
        emailRedirectTo: Env.authRedirectUrl,
      );
      await Observability.track('account_email_change_requested');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enviamos um link de confirmação para o novo e-mail. '
            'Confirme para concluir a troca.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    } on Object catch (e, st) {
      await Observability.captureError(e, st, hint: 'update_email');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensagemDeErro(
              e,
              fallback: 'Não foi possível salvar. Tente novamente.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  Future<void> _salvarSenha() async {
    final atual = _senhaAtualCtrl.text;
    final nova = _senhaNovaCtrl.text;
    if (nova.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha nova precisa de no mínimo 8 chars.'),
        ),
      );
      return;
    }
    setState(() => _savingSenha = true);
    try {
      final client = _requireClient(context);
      final email = client.auth.currentUser?.email;
      if (email == null) {
        throw StateError('Sem e-mail associado.');
      }
      // Reautentica antes de trocar — protege contra sessão antiga.
      await client.auth.signInWithPassword(email: email, password: atual);
      await client.auth.updateUser(UserAttributes(password: nova));
      await Observability.track('account_password_updated');
      _senhaAtualCtrl.clear();
      _senhaNovaCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Senha atualizada.')));
    } on AuthException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Senha atual incorreta ou não foi possível alterar a senha.',
          ),
        ),
      );
    } on Object catch (e, st) {
      await Observability.captureError(e, st, hint: 'update_password');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensagemDeErro(
              e,
              fallback: 'Não foi possível salvar. Tente novamente.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingSenha = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(isGuestProvider);

    if (isGuest || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conta')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.no_accounts_outlined,
                    size: 32,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTheme.space16),
                Text(
                  'Você está em modo convidado.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.space8),
                Text(
                  'Crie uma conta para sincronizar entre dispositivos.',
                  style: AppTheme.label(11, color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.space20),
                FilledButton(
                  onPressed: () => context.push('/sign-up'),
                  child: const Text('CRIAR CONTA'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _AccountSection(
            title: 'PERFIL',
            scheme: scheme,
            children: [
              TextField(
                controller: _nomeCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(
                    Icons.person_outline,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              FilledButton(
                onPressed: _savingNome ? null : _salvarNome,
                child: _SavingLabel(saving: _savingNome, label: 'SALVAR NOME'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space20),
          _AccountSection(
            title: 'E-MAIL',
            scheme: scheme,
            children: [
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(
                    Icons.mail_outline,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              Text(
                'Mudar o e-mail dispara um link de confirmação para o novo '
                'endereço.',
                style: AppTheme.label(11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.space12),
              FilledButton(
                onPressed: _savingEmail ? null : _salvarEmail,
                child: _SavingLabel(
                  saving: _savingEmail,
                  label: 'SALVAR E-MAIL',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space20),
          _AccountSection(
            title: 'SENHA',
            scheme: scheme,
            children: [
              TextField(
                controller: _senhaAtualCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha atual',
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              TextField(
                controller: _senhaNovaCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha nova (mínimo 8)',
                  prefixIcon: Icon(
                    Icons.lock_reset_outlined,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space12),
              FilledButton(
                onPressed: _savingSenha ? null : _salvarSenha,
                child: _SavingLabel(
                  saving: _savingSenha,
                  label: 'TROCAR SENHA',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space32),
          Text(
            'ID: ${user.id}',
            style: AppTheme.mono(11).copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Card de seção — substitui a lista separada por `Divider` por respiro e
/// agrupamento visual (design-system.md §1 "espaço é conteúdo").
class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.title,
    required this.scheme,
    required this.children,
  });

  final String title;
  final ColorScheme scheme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(title: title, scheme: scheme),
            const SizedBox(height: AppTheme.space12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Rótulo de botão que troca com fade (sem "bounce") pro spinner de
/// carregamento — feedback de estado consistente entre os 3 formulários da
/// tela (design-system.md §3 movimento é feedback).
class _SavingLabel extends StatelessWidget {
  const _SavingLabel({required this.saving, required this.label});

  final bool saving;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppTheme.motionFast,
      child: saving
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.onLimeAccent,
              ),
            )
          : Text(label, key: const ValueKey('label')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.scheme});
  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 14, color: scheme.primary),
        const SizedBox(width: AppTheme.space8),
        Text(
          title,
          style: AppTheme.label(
            11,
            color: scheme.onSurface,
          ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.18),
        ),
      ],
    );
  }
}
