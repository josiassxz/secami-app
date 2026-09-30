import '../../features/auth/data/rest_auth_service.dart';

/// Regras de acesso por papel no modo SECAMI (`Env.hasRestApi`), separadas do
/// GoRouter pra serem testáveis sem subir o app.
///
/// Papéis do backend: `aluno` e `professor` (na interface, "Instrutor").
/// Admin/recepção podem logar no app, mas não têm telas próprias aqui.

/// Rotas que só fazem sentido pra quem tem cadastro de aluno — dependem de
/// `/me/student`, `/me/appointments`, `/me/workout-plans` e do vínculo com
/// treinador, que o backend só resolve para o papel `aluno`.
const rotasSomenteAluno = {
  '/academia/agenda',
  '/academia/treino',
  '/academia/perfil',
  '/coach/treinador',
};

/// Prefixo das telas do perfil Instrutor (alunos e fichas de treino).
const prefixoRotasInstrutor = '/instrutor';

/// Rotas de entrada/cadastro: sem sentido pra quem já está logado.
const _semSentidoLogado = {
  '/',
  '/sign-in',
  '/sign-up',
  '/forgot-password',
  '/cadastro',
};

/// Rotas abertas sem sessão (login e auto-cadastro público de aluno).
const _rotasPublicas = {'/sign-in', '/cadastro'};

/// Tela de entrada pós-login. Quem é só instrutor cai direto na Academia
/// (onde fica "Alunos e Fichas"); os demais, no diário de treinos.
String rotaInicialSecami(SecamiUser? user) =>
    (user?.isSomenteInstrutor ?? false) ? '/academia' : '/routines';

/// Decide o redirect do GoRouter no modo SECAMI. Retorna `null` quando a
/// rota [loc] pode ser aberta pelo usuário [user].
String? secamiRedirect(SecamiUser? user, String loc) {
  if (user == null) {
    return _rotasPublicas.contains(loc) ? null : '/sign-in';
  }
  if (_semSentidoLogado.contains(loc)) return rotaInicialSecami(user);
  if (!user.isAluno && rotasSomenteAluno.contains(loc)) return '/academia';
  if (!user.isInstrutor && loc.startsWith(prefixoRotasInstrutor)) {
    return '/academia';
  }
  return null;
}
