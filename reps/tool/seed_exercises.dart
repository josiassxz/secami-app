// Gera supabase/seeds/0001_exercises_seed.sql a partir da lista
// exercisesSeed em lib/features/library/data/exercises_seed.dart.
//
// Uso:
//   dart run tool/seed_exercises.dart

import 'dart:io';

// ignore: avoid_relative_lib_imports
import '../lib/features/library/data/exercises_seed.dart';

String esc(String s) => s.replaceAll("'", "''");

void main() {
  final buffer = StringBuffer();
  buffer.writeln('-- Auto-gerado por tool/seed_exercises.dart');
  buffer.writeln(
    '-- Insere ${exercisesSeed.length} exercicios na biblioteca global.',
  );
  buffer.writeln('-- Idempotente: usa upsert por slug.');
  buffer.writeln();
  buffer.writeln('begin;');
  buffer.writeln();

  for (final e in exercisesSeed) {
    final secundarios = e.gruposSecundarios.isEmpty
        ? "'{}'"
        : "ARRAY[${e.gruposSecundarios.map((g) => "'${g.name}'").join(',')}]::grupo_muscular[]";

    buffer.writeln(
      "insert into public.exercises "
      "(slug, nome, descricao, gif_url, grupo_muscular_primario, "
      "grupo_muscular_secundario, padrao_movimento, equipamento) values (",
    );
    buffer.writeln("  '${esc(e.slug)}',");
    buffer.writeln("  '${esc(e.nome)}',");
    buffer.writeln("  '${esc(e.descricao)}',");
    buffer.writeln("  '${esc(e.slug)}',");
    buffer.writeln("  '${e.grupoPrimario.name}',");
    buffer.writeln('  $secundarios,');
    buffer.writeln("  '${e.padrao.name}',");
    buffer.writeln("  '${e.equipamento.name}'");
    buffer.writeln(') on conflict (slug) do update set');
    buffer.writeln('  nome = excluded.nome,');
    buffer.writeln('  descricao = excluded.descricao,');
    buffer.writeln('  gif_url = excluded.gif_url,');
    buffer.writeln(
      '  grupo_muscular_primario = excluded.grupo_muscular_primario,',
    );
    buffer.writeln(
      '  grupo_muscular_secundario = excluded.grupo_muscular_secundario,',
    );
    buffer.writeln('  padrao_movimento = excluded.padrao_movimento,');
    buffer.writeln('  equipamento = excluded.equipamento;');
    buffer.writeln();
  }

  buffer.writeln('commit;');

  const outPath = 'supabase/seeds/0001_exercises_seed.sql';
  final file = File(outPath);
  file.createSync(recursive: true);
  file.writeAsStringSync(buffer.toString());

  // ignore: avoid_print
  stdout.writeln('Gerado: $outPath (${exercisesSeed.length} exercicios)');
}
