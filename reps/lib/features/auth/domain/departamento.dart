/// Secretaria/orgao do governo de Goias, usado no combo do formulario de
/// auto-cadastro (`GET /cadastro/departamentos` — publico, sem token).
class Departamento {
  const Departamento({
    required this.id,
    required this.name,
    required this.sigla,
    required this.andar,
    required this.active,
  });

  final String id;
  final String name;
  final String sigla;
  final String? andar;
  final bool active;

  /// Rotulo pronto pro dropdown: "Sigla — Nome".
  String get rotulo => sigla.isEmpty ? name : '$sigla — $name';

  factory Departamento.fromJson(Map<String, dynamic> json) => Departamento(
    id: json['id'] as String,
    name: json['name'] as String,
    sigla: (json['sigla'] as String?) ?? '',
    andar: json['andar']?.toString(),
    active: (json['active'] as bool?) ?? true,
  );
}
